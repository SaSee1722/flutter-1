import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/repositories/call_repository.dart';

class WebRTCService {
  final CallRepository _callRepository;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
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

  Future<void> initLocalStream(bool isVideo) async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': isVideo,
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> createCall(String receiverId, String callId) async {
    _peerConnection = await createPeerConnection(_iceServers);
    
    _peerConnection!.onIceCandidate = (candidate) {
      _callRepository.addIceCandidate(callId, candidate, true);
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
    await _callRepository.makeCall(receiverId, offer);
  }

  Future<void> joinCall(String callId, RTCSessionDescription offer) async {
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
    await _peerConnection?.addCandidate(candidate);
  }

  Future<void> setRemoteDescription(RTCSessionDescription answer) async {
    await _peerConnection?.setRemoteDescription(answer);
  }

  void dispose() {
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
  }
}
