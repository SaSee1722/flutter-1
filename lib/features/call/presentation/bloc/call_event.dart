import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class CallEvent extends Equatable {
  const CallEvent();
  @override
  List<Object?> get props => [];
}

class InitializeCallBloc extends CallEvent {
  final String userId;
  const InitializeCallBloc(this.userId);

  @override
  List<Object?> get props => [userId];
}

class StartCall extends CallEvent {
  final String? receiverId;
  final String? roomId;
  final String name;
  final String? avatar;
  final bool isVideo;

  const StartCall({
    this.receiverId,
    this.roomId,
    required this.name,
    this.avatar,
    required this.isVideo,
  });

  @override
  List<Object?> get props => [receiverId, roomId, name, avatar, isVideo];
}

class IncomingCallReceived extends CallEvent {
  final Map<String, dynamic> callData;
  const IncomingCallReceived(this.callData);
}

class AnswerCall extends CallEvent {
  final String callId;
  const AnswerCall(this.callId);
}

class RejectCall extends CallEvent {
  final String callId;
  const RejectCall(this.callId);
}

class EndCall extends CallEvent {
  final String callId;
  const EndCall(this.callId);
}

class ToggleMute extends CallEvent {}

class ToggleVideo extends CallEvent {}

class ToggleSpeaker extends CallEvent {}

class RemoteAnswerReceived extends CallEvent {
  final RTCSessionDescription answer;
  const RemoteAnswerReceived(this.answer);
}

class IceCandidateReceived extends CallEvent {
  final RTCIceCandidate candidate;
  const IceCandidateReceived(this.candidate);
}

class RemoteParticipantStatusChanged extends CallEvent {
  final String status;
  const RemoteParticipantStatusChanged(this.status);
}

class CallTimeout extends CallEvent {}

class CallTimerTicked extends CallEvent {
  final int duration;
  const CallTimerTicked(this.duration);

  @override
  List<Object?> get props => [duration];
}

class RemoteVideoStatusChanged extends CallEvent {
  final bool isVideo;
  const RemoteVideoStatusChanged(this.isVideo);
}

class RemoteStreamReceived extends CallEvent {}

class RenegotiationOfferReceived extends CallEvent {
  final RTCSessionDescription offer;
  const RenegotiationOfferReceived(this.offer);

  @override
  List<Object?> get props => [offer];
}
