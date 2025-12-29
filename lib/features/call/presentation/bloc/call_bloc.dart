import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../data/webrtc_service.dart';
import '../../domain/repositories/call_repository.dart';
import '../../../chat/domain/repositories/chat_repository.dart';
import '../../../../core/services/call_sound_service.dart';
import 'call_event.dart';
import 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  final WebRTCService _webRTCService;
  final CallRepository _callRepository;
  final ChatRepository _chatRepository;
  final CallSoundService _soundService;
  String? _currentUserId;
  Map<String, dynamic>? _currentUserProfile;
  StreamSubscription? _incomingCallsSub;
  StreamSubscription? _callUpdateSub;
  StreamSubscription? _iceCandidatesSub;
  Timer? _callTimeoutTimer;
  Timer? _callDurationTimer;

  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  CallBloc({
    required WebRTCService webRTCService,
    required CallRepository callRepository,
    required ChatRepository chatRepository,
    required CallSoundService soundService,
  })  : _webRTCService = webRTCService,
        _callRepository = callRepository,
        _chatRepository = chatRepository,
        _soundService = soundService,
        super(CallIdle()) {
    _initRenderers();

    on<InitializeCallBloc>((event, emit) async {
      _currentUserId = event.userId;
      _listenForIncomingCalls();
      // Set online status and fetch profile
      await _chatRepository.setOnlineStatus(true);
      try {
        _currentUserProfile = await _chatRepository.getProfile(event.userId);
      } catch (e) {
        debugPrint('Error fetching caller profile: $e');
      }
    });

    on<StartCall>(_onStartCall);
    on<IncomingCallReceived>(_onIncomingCallReceived);
    on<AnswerCall>(_onAnswerCall);
    on<RejectCall>(_onRejectCall);
    on<EndCall>(_onEndCall);
    on<RemoteAnswerReceived>(_onRemoteAnswerReceived);
    on<IceCandidateReceived>(_onIceCandidateReceived);
    on<ToggleMute>(_onToggleMute);
    on<ToggleVideo>(_onToggleVideo);
    on<ToggleSpeaker>(_onToggleSpeaker);
    on<RemoteParticipantStatusChanged>(_onRemoteStatusChanged);
    on<CallTimeout>(_onCallTimeout);
    on<CallTimerTicked>(_onCallTimerTicked);
    on<RemoteVideoStatusChanged>((event, emit) {
      if (state is CallActive) {
        final s = state as CallActive;
        // Update isVideo to show the video UI
        emit(s.copyWith(
          isVideo: event.isVideo,
          lastUpdate: DateTime.now(),
        ));
      }
    });

    on<RemoteStreamReceived>((event, emit) {
      if (state is CallActive) {
        final s = state as CallActive;
        emit(s.copyWith(
          remoteRenderers: {'default': remoteRenderer},
          lastUpdate: DateTime.now(),
        ));
      }
    });

    _webRTCService.onRemoteStream = (stream) {
      remoteRenderer.srcObject = stream;
      add(RemoteStreamReceived());
    };
  }

  Future<void> _initRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void _listenForIncomingCalls() {
    _incomingCallsSub?.cancel();
    if (_currentUserId == null || _currentUserId!.isEmpty) return;

    _incomingCallsSub =
        _callRepository.onIncomingCalls(_currentUserId!).listen((calls) {
      if (calls.isNotEmpty && state is CallIdle) {
        add(IncomingCallReceived(calls.first));
      } else if (calls.isEmpty && state is CallRinging) {
        final s = state as CallRinging;
        if (s.isIncoming) {
          add(const RemoteParticipantStatusChanged("ended"));
        }
      }
    });
  }

  Future<void> _onStartCall(StartCall event, Emitter<CallState> emit) async {
    try {
      if (_currentUserId == null) throw Exception("User not authenticated");

      final actuallyVideo = await _webRTCService.initLocalStream(event.isVideo);
      localRenderer.srcObject = _webRTCService.localStream;

      // Ensure profile is loaded before starting call
      if (_currentUserProfile == null && _currentUserId != null) {
        _currentUserProfile = await _chatRepository.getProfile(_currentUserId!);
      }

      final callId = await _webRTCService.createCall(
        receiverId: event.receiverId,
        roomId: event.roomId,
        isVideo: actuallyVideo,
        callerName: event.roomId != null
            ? "${event.name} (${_currentUserProfile?['username'] ?? "Someone"})"
            : (_currentUserProfile?['username'] ?? "Someone"),
        callerAvatar: event.roomId != null
            ? event.avatar
            : _currentUserProfile?['avatar_url'],
      );

      _listenToCallUpdates(callId);
      _listenToIceCandidates(callId);

      emit(CallRinging(
        callId: callId,
        callerName: event.name,
        callerAvatar: event.avatar,
        isVideo: actuallyVideo,
        isIncoming: false,
      ));

      _startTimeoutTimer();
      await _soundService.playRinging();
    } catch (e) {
      emit(CallError(e.toString()));
    }
  }

  void _startTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = Timer(const Duration(seconds: 15), () {
      add(CallTimeout());
    });
  }

  void _stopTimeoutTimer() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  Future<void> _onCallTimeout(
      CallTimeout event, Emitter<CallState> emit) async {
    final currentState = state;
    if (currentState is CallRinging) {
      await _callRepository.endCall(currentState.callId);
      _cleanup();
      emit(const CallError("No response"));
      await Future.delayed(const Duration(seconds: 2));
      emit(CallIdle());
    }
  }

  void _onCallTimerTicked(CallTimerTicked event, Emitter<CallState> emit) {
    if (state is CallActive) {
      emit((state as CallActive).copyWith(duration: event.duration));
    }
  }

  void _startCallTimer() {
    _stopCallTimer();
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      add(CallTimerTicked(timer.tick));
    });
  }

  void _stopCallTimer() {
    _callDurationTimer?.cancel();
    _callDurationTimer = null;
  }

  void _onIncomingCallReceived(
      IncomingCallReceived event, Emitter<CallState> emit) {
    emit(CallRinging(
      callId: event.callData['id'],
      callerName: event.callData['caller_name'] ?? "Incoming Call",
      callerAvatar: event.callData['caller_avatar'],
      isVideo: event.callData['is_video'] ?? false,
      isIncoming: true,
    ));
    _startTimeoutTimer();
    // Use system ringtone via CallKit usually, but if custom in-app handling needed:
    // _soundService.playRinging();
  }

  Future<void> _onAnswerCall(AnswerCall event, Emitter<CallState> emit) async {
    final currentState = state;
    if (currentState is! CallRinging) return;

    try {
      final actuallyVideo =
          await _webRTCService.initLocalStream(currentState.isVideo);
      localRenderer.srcObject = _webRTCService.localStream;

      final callData = await _callRepository.onCallUpdate(event.callId).first;
      final offerMap = callData['offer'] as Map<String, dynamic>;
      final offer = RTCSessionDescription(
        offerMap['sdp'],
        offerMap['type'],
      );

      await _webRTCService.joinCall(event.callId, offer);
      _listenToIceCandidates(event.callId);
      _listenToCallUpdates(event.callId);
      _stopTimeoutTimer();

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          Helper.setSpeakerphoneOn(true);
        } catch (e) {
          debugPrint('Speakerphone error: $e');
        }
      }
      emit(CallActive(
        callId: event.callId,
        remoteName: currentState.callerName,
        remoteAvatar: currentState.callerAvatar,
        localRenderer: localRenderer,
        remoteRenderers: {'default': remoteRenderer},
        isVideo: actuallyVideo,
        isVideoOff: !actuallyVideo,
        isSpeakerOn: true,
        lastUpdate: DateTime.now(),
      ));
      _startCallTimer();
      await _soundService.playConnected();
    } catch (e) {
      emit(CallError(e.toString()));
    }
  }

  Future<void> _onRejectCall(RejectCall event, Emitter<CallState> emit) async {
    _stopTimeoutTimer();
    await _callRepository.rejectCall(event.callId);
    _cleanup();
    emit(CallIdle());
  }

  Future<void> _onEndCall(EndCall event, Emitter<CallState> emit) async {
    int? duration;
    if (state is CallActive) {
      duration = (state as CallActive).duration;
    }
    _stopTimeoutTimer();
    await _callRepository.endCall(event.callId, duration: duration);
    _cleanup();
    emit(CallEnded());
    await _soundService.playEnded();
    await Future.delayed(const Duration(seconds: 1));
    emit(CallIdle());
  }

  void _listenToCallUpdates(String callId) {
    _callUpdateSub?.cancel();
    _callUpdateSub = _callRepository.onCallUpdate(callId).listen((update) {
      if (update['status'] == 'accepted' &&
          update['answer'] != null &&
          state is CallRinging) {
        final answerMap = update['answer'] as Map<String, dynamic>;
        final answer = RTCSessionDescription(
          answerMap['sdp'],
          answerMap['type'],
        );
        add(RemoteAnswerReceived(answer));
      } else if (update['status'] == 'rejected' ||
          update['status'] == 'ended') {
        add(RemoteParticipantStatusChanged(update['status']));
      }

      // Track mid-call video upgrades
      if (update['is_video'] == true && state is CallActive) {
        final s = state as CallActive;
        if (!s.isVideo) {
          add(const RemoteVideoStatusChanged(true));
        }
      }
    });
  }

  void _listenToIceCandidates(String callId) {
    _iceCandidatesSub?.cancel();
    _iceCandidatesSub =
        _callRepository.onIceCandidates(callId).listen((candidates) {
      for (var data in candidates) {
        final isMyCandidate =
            (state is CallRinging && !(state as CallRinging).isIncoming)
                ? data['is_caller'] == true
                : data['is_caller'] == false;

        if (!isMyCandidate) {
          final candidateMap = data['candidate'] as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            candidateMap['candidate'],
            candidateMap['sdpMid'],
            candidateMap['sdpMLineIndex'],
          );
          add(IceCandidateReceived(candidate));
        }
      }
    });
  }

  Future<void> _onRemoteAnswerReceived(
      RemoteAnswerReceived event, Emitter<CallState> emit) async {
    _stopTimeoutTimer();
    await _webRTCService.setRemoteDescription(event.answer);
    final currentState = state;
    if (currentState is CallRinging) {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          Helper.setSpeakerphoneOn(true);
        } catch (e) {
          debugPrint('Speakerphone error: $e');
        }
      }
      emit(CallActive(
        callId: currentState.callId,
        remoteName: currentState.callerName,
        remoteAvatar: currentState.callerAvatar,
        localRenderer: localRenderer,
        remoteRenderers: {'default': remoteRenderer},
        isVideo: currentState.isVideo,
        isVideoOff: !currentState.isVideo,
        isSpeakerOn: true,
        lastUpdate: DateTime.now(),
      ));
      _startCallTimer();
      await _soundService.playConnected();
    }
  }

  Future<void> _onIceCandidateReceived(
      IceCandidateReceived event, Emitter<CallState> emit) async {
    await _webRTCService.addCandidate(event.candidate);
  }

  void _onToggleMute(ToggleMute event, Emitter<CallState> emit) {
    if (state is CallActive) {
      final s = state as CallActive;
      final newMuted = !s.isMuted;
      _webRTCService.toggleMic(!newMuted);
      emit(s.copyWith(isMuted: newMuted));
    }
  }

  Future<void> _onToggleVideo(
      ToggleVideo event, Emitter<CallState> emit) async {
    if (state is CallActive) {
      final s = state as CallActive;
      final newVideoOff = !s.isVideoOff;
      await _webRTCService.toggleVideo(!newVideoOff);

      // Update the database so the other side knows to switch UI
      try {
        _callRepository.updateCallVideoStatus(s.callId, !newVideoOff);
      } catch (e) {
        debugPrint('Error updating video status in DB: $e');
      }

      // Re-assign srcObject and trigger UI refresh
      localRenderer.srcObject = _webRTCService.localStream;

      // If we are turning video ON, ensure isVideo is also true so UI switches from audio placeholder
      emit(s.copyWith(
        isVideoOff: newVideoOff,
        isVideo: !newVideoOff ? true : s.isVideo,
        lastUpdate: DateTime.now(),
      ));
    }
  }

  void _onToggleSpeaker(ToggleSpeaker event, Emitter<CallState> emit) {
    if (state is CallActive) {
      final s = state as CallActive;
      final newSpeakerOn = !s.isSpeakerOn;
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          Helper.setSpeakerphoneOn(newSpeakerOn);
        } catch (e) {
          debugPrint('Speakerphone error: $e');
        }
      }
      emit(s.copyWith(isSpeakerOn: newSpeakerOn));
    }
  }

  Future<void> _onRemoteStatusChanged(
      RemoteParticipantStatusChanged event, Emitter<CallState> emit) async {
    final currentState = state;
    String? callId;
    int? duration;

    if (currentState is CallActive) {
      callId = currentState.callId;
      duration = currentState.duration;
    } else if (currentState is CallRinging) {
      callId = currentState.callId;
    }

    _cleanup();

    if (callId != null && event.status == 'ended') {
      await _callRepository.endCall(callId, duration: duration);
    }

    if (event.status == 'rejected') {
      emit(const CallError("Call rejected"));
    } else {
      emit(CallEnded());
      await _soundService.playEnded();
    }
    await Future.delayed(const Duration(seconds: 2));
    if (!emit.isDone) {
      emit(CallIdle());
    }
  }

  void _cleanup() {
    _soundService.stop();
    _stopTimeoutTimer();
    _stopCallTimer();
    _webRTCService.dispose();
    _callUpdateSub?.cancel();
    _iceCandidatesSub?.cancel();
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  @override
  Future<void> close() {
    _incomingCallsSub?.cancel();
    _cleanup();
    localRenderer.dispose();
    remoteRenderer.dispose();
    return super.close();
  }
}
