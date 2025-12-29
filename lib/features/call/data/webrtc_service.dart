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

  WebRTCService(this._callRepository);

  final _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<bool> initLocalStream(bool isVideo) async {
    // Request permissions first
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.microphone,
        Permission.camera,
        Permission.bluetoothConnect,
      ].request();
      debugPrint('Permission statuses: $statuses');
    }

    // We always try to get both to avoid mid-call renegotiation issues
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': true,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      // If the user specifically wanted audio only, we disable the video track for now
      if (!isVideo) {
        _localStream?.getVideoTracks().forEach((track) {
          track.enabled = false;
        });
      }

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
          'audio': true,
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

  Future<String> createCall({
    String? receiverId,
    String? roomId,
    required bool isVideo,
    String? callerName,
    String? callerAvatar,
  }) async {
    _earlyCandidates.clear();
    _peerConnection = await createPeerConnection(_iceServers);
    _currentCallId = null;

    _peerConnection!.onIceCandidate = (candidate) {
      if (_currentCallId != null) {
        _callRepository.addIceCandidate(_currentCallId!, candidate, true);
      } else {
        _earlyCandidates.add(candidate);
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    for (var track in _localStream!.getTracks()) {
      _peerConnection!.addTrack(track, _localStream!);
    }

    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _currentCallId = await _callRepository.makeCall(
      receiverId: receiverId,
      roomId: roomId,
      isVideo: isVideo,
      offer: offer,
      callerName: callerName,
      callerAvatar: callerAvatar,
    );

    // Send buffered candidates
    for (var candidate in _earlyCandidates) {
      _callRepository.addIceCandidate(_currentCallId!, candidate, true);
    }
    _earlyCandidates.clear();

    return _currentCallId!;
  }

  Future<void> joinCall(String callId, RTCSessionDescription offer) async {
    _currentCallId = callId;
    _peerConnection = await createPeerConnection(_iceServers);

    _peerConnection!.onIceCandidate = (candidate) {
      _callRepository.addIceCandidate(callId, candidate, false);
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
      }
    };

    for (var track in _localStream!.getTracks()) {
      _peerConnection!.addTrack(track, _localStream!);
    }

    await _peerConnection!.setRemoteDescription(offer);
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _callRepository.answerCall(callId, answer);
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection != null) {
      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc != null) {
        await _peerConnection!.addCandidate(candidate);
      } else {
        debugPrint(
            'ICE Candidate received but remote description is null, skipping...');
      }
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription answer) async {
    await _peerConnection?.setRemoteDescription(answer);
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

  void dispose() {
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
  }
}
