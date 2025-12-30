import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class CallState extends Equatable {
  const CallState();
  @override
  List<Object?> get props => [];
}

class CallIdle extends CallState {}

class CallRinging extends CallState {
  final String callId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideo;
  final bool isIncoming;
  final bool autoAnswer;

  const CallRinging({
    required this.callId,
    required this.callerName,
    this.callerAvatar,
    required this.isVideo,
    required this.isIncoming,
    this.autoAnswer = false,
  });

  @override
  List<Object?> get props =>
      [callId, callerName, callerAvatar, isVideo, isIncoming, autoAnswer];
}

class CallActive extends CallState {
  final String callId;
  final String? remoteName; // Fallback for 1-1
  final String? remoteAvatar;
  final RTCVideoRenderer localRenderer;
  final Map<String, RTCVideoRenderer> remoteRenderers;
  final bool isMuted;
  final bool isVideoOff;
  final bool isSpeakerOn;
  final bool isVideo; // Initial call type
  final int duration; // In seconds

  const CallActive({
    required this.callId,
    this.remoteName,
    this.remoteAvatar,
    required this.localRenderer,
    required this.remoteRenderers,
    this.isMuted = false,
    this.isVideoOff = false,
    this.isSpeakerOn = false,
    required this.isVideo,
    this.duration = 0,
    this.lastUpdate,
  });

  @override
  List<Object?> get props => [
        callId,
        remoteName,
        remoteAvatar,
        localRenderer,
        remoteRenderers,
        isMuted,
        isVideoOff,
        isSpeakerOn,
        isVideo,
        duration,
        lastUpdate,
      ];

  final DateTime? lastUpdate;

  CallActive copyWith({
    bool? isMuted,
    bool? isVideoOff,
    bool? isSpeakerOn,
    Map<String, RTCVideoRenderer>? remoteRenderers,
    bool? isVideo,
    int? duration,
    DateTime? lastUpdate,
  }) {
    return CallActive(
      callId: callId,
      remoteName: remoteName,
      remoteAvatar: remoteAvatar,
      localRenderer: localRenderer,
      remoteRenderers: remoteRenderers ?? this.remoteRenderers,
      isMuted: isMuted ?? this.isMuted,
      isVideoOff: isVideoOff ?? this.isVideoOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideo: isVideo ?? this.isVideo,
      duration: duration ?? this.duration,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }

  String get formattedDuration {
    final minutes = (duration / 60).floor();
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class CallEnded extends CallState {}

class CallError extends CallState {
  final String message;
  const CallError(this.message);
  @override
  List<Object?> get props => [message];
}
