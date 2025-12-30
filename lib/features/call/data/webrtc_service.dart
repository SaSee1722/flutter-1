import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/repositories/call_repository.dart';
import 'package:permission_handler/permission_handler.dart';

class WebRTCService {
  final CallRepository _callRepository;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStream? get localStream => _localStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onStatusUpdate;
  Function(RTCSessionDescription)? onRenegotiationNeeded;

  WebRTCService(this._callRepository);

  final _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<bool> initLocalStream(bool isVideo) async {
    debugPrint('[WebRTC] Initializing local stream (isVideo: $isVideo)');

    // Request permissions first
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.camera,
        Permission.bluetoothConnect,
      ].request();
      debugPrint('[WebRTC] Permission statuses: $statuses');
    }

    // We always try to get both to avoid mid-call renegotiation issues
    // Use explicit audio constraints for better mobile compatibility
    final Map<String, dynamic> constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isVideo,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // CRITICAL: Ensure audio tracks are enabled and video is set correctly
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = true;
        debugPrint(
            '[WebRTC] Local audio track added: ${track.id}, enabled: ${track.enabled}');
      });

      _localStream?.getVideoTracks().forEach((track) {
        debugPrint(
            '[WebRTC] Local video track added: ${track.id}, enabled: ${track.enabled}');
      });

      // Ensure audio is routed correctly (Mobile only)
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          await Helper.setSpeakerphoneOn(true);
        } catch (e) {
          debugPrint('Speakerphone not supported on this platform: $e');
        }
      }
      return isVideo; // Return intended call type
    } catch (e) {
      if (isVideo) {
        debugPrint('Full media access failed, trying audio only: $e');
        final audioOnly = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
            'googEchoCancellation': true,
            'googNoiseSuppression': true,
            'googAutoGainControl': true,
            'googHighpassFilter': true,
          },
          'video': false,
        });
        _localStream = audioOnly;
        return false; // Fallback to audio mode
      } else {
        debugPrint('Media access failed: $e');
        rethrow;
      }
    }
  }

  String? _currentCallId;
  final List<RTCIceCandidate> _earlyCandidates = [];
  final List<RTCIceCandidate> _remoteEarlyCandidates = [];

  Future<String> createCall({
    String? receiverId,
    String? roomId,
    required bool isVideo,
    String? callerName,
    String? callerAvatar,
  }) async {
    debugPrint('[WebRTC] Creating call (isVideo: $isVideo)');
    _earlyCandidates.clear();
    _peerConnection = await createPeerConnection(_iceServers);
    _currentCallId = null;

    // Set up ICE candidate handler
    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('[WebRTC] ICE candidate generated');
      if (_currentCallId != null) {
        _callRepository.addIceCandidate(_currentCallId!, candidate, true);
      } else {
        _earlyCandidates.add(candidate);
      }
    };

    // Set up remote track handler
    _peerConnection!.onTrack = (event) {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        debugPrint(
            '[WebRTC] Remote stream set with ${_remoteStream!.getTracks().length} tracks');
        onRemoteStream?.call(_remoteStream!);
      } else {
        debugPrint(
            '[WebRTC] No stream in onTrack, creating one for ${event.track.id}');
        _ensureRemoteStreamAndAddTrack(event.track);
      }
    };

    // Set up connection state listeners
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Peer connection state: $state');
      onStatusUpdate?.call('Connection: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state: $state');
    };

    // CRITICAL: Add tracks BEFORE creating offer
    debugPrint(
        '[WebRTC] Adding ${_localStream!.getTracks().length} local tracks');
    for (var track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint(
          '[WebRTC] Added ${track.kind} track: ${track.id}, enabled: ${track.enabled}');

      // Ensure all tracks are enabled
      track.enabled = true;
    }

    // Create offer AFTER adding tracks
    debugPrint('[WebRTC] Creating offer...');
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    debugPrint('[WebRTC] Offer created and set as local description');

    _currentCallId = await _callRepository.makeCall(
      receiverId: receiverId,
      roomId: roomId,
      isVideo: isVideo,
      offer: offer,
      callerName: callerName,
      callerAvatar: callerAvatar,
    );
    debugPrint('[WebRTC] Call created with ID: $_currentCallId');

    // Send buffered candidates
    for (var candidate in _earlyCandidates) {
      _callRepository.addIceCandidate(_currentCallId!, candidate, true);
    }
    _earlyCandidates.clear();

    return _currentCallId!;
  }

  Future<void> joinCall(String callId, RTCSessionDescription offer) async {
    debugPrint('[WebRTC] Joining call: $callId');
    _currentCallId = callId;
    _peerConnection = await createPeerConnection(_iceServers);

    // Set up ICE candidate handler
    _peerConnection!.onIceCandidate = (candidate) {
      debugPrint('[WebRTC] ICE candidate generated (answerer)');
      _callRepository.addIceCandidate(callId, candidate, false);
    };

    // Set up remote track handler
    _peerConnection!.onTrack = (event) {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        debugPrint(
            '[WebRTC] Remote stream set with ${_remoteStream!.getTracks().length} tracks');
        onRemoteStream?.call(_remoteStream!);
      } else {
        debugPrint(
            '[WebRTC] No stream in onTrack, creating one for ${event.track.id}');
        _ensureRemoteStreamAndAddTrack(event.track);
      }
    };

    // Set up connection state listeners
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Peer connection state: $state');
      onStatusUpdate?.call('Connection: $state');
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state: $state');
    };

    // CRITICAL: Add tracks BEFORE setting remote description
    debugPrint(
        '[WebRTC] Adding ${_localStream!.getTracks().length} local tracks');
    for (var track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
      debugPrint(
          '[WebRTC] Added ${track.kind} track: ${track.id}, enabled: ${track.enabled}');

      // Ensure all tracks are enabled
      track.enabled = true;
    }

    // Set remote description (the offer)
    debugPrint('[WebRTC] Setting remote description (offer)');
    await _peerConnection!.setRemoteDescription(offer);

    // Create answer
    debugPrint('[WebRTC] Creating answer...');
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    debugPrint('[WebRTC] Answer created and set as local description');

    // Send answer to caller
    await _callRepository.answerCall(callId, answer);
    debugPrint('[WebRTC] Answer sent to caller');
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection != null) {
      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc != null) {
        await _peerConnection!.addCandidate(candidate);
        debugPrint('[WebRTC] ICE Candidate added');
      } else {
        _remoteEarlyCandidates.add(candidate);
        debugPrint(
            '[WebRTC] ICE Candidate buffered (Remote description not yet set)');
      }
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription answer) async {
    if (_peerConnection == null) return;
    await _peerConnection!.setRemoteDescription(answer);
    debugPrint(
        '[WebRTC] Remote description set, processing buffered candidates');

    // Process buffered candidates
    for (var candidate in _remoteEarlyCandidates) {
      await _peerConnection!.addCandidate(candidate);
    }
    _remoteEarlyCandidates.clear();
  }

  Future<void> toggleVideo(bool enabled) async {
    if (_localStream == null) return;

    if (enabled && _localStream!.getVideoTracks().isEmpty) {
      // Stream doesn't have video, try to add it
      try {
        final videoStream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': true,
        });
        if (videoStream.getVideoTracks().isNotEmpty) {
          final videoTrack = videoStream.getVideoTracks().first;
          await _localStream!.addTrack(videoTrack);
          if (_peerConnection != null) {
            await _peerConnection!.addTrack(videoTrack, _localStream!);

            // CRITICAL: Renegotiate the connection so the other peer receives the video
            debugPrint('Video track added, triggering renegotiation');
            final offer = await _peerConnection!.createOffer();
            await _peerConnection!.setLocalDescription(offer);

            // Notify the bloc to send this new offer to the remote peer
            onRenegotiationNeeded?.call(offer);
          }
        }
      } catch (e) {
        debugPrint('Error adding video track: $e');
        return;
      }
    }

    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  Future<void> toggleMic(bool enabled) async {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  Future<void> _ensureRemoteStreamAndAddTrack(MediaStreamTrack track) async {
    _remoteStream ??= await createLocalMediaStream('remote_stream_${track.id}');
    await _remoteStream!.addTrack(track);
    debugPrint(
        '[WebRTC] Track added to remote stream. Total tracks: ${_remoteStream!.getTracks().length}');
    onRemoteStream?.call(_remoteStream!);
  }

  void dispose() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.getTracks().forEach((t) => t.stop());
    _remoteStream?.dispose();
    _peerConnection?.dispose();
  }
}
