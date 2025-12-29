import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/status_repository.dart';
import '../../domain/entities/user_status.dart';
import 'vibe_event.dart';
import 'vibe_state.dart';

class VibeBloc extends Bloc<VibeEvent, VibeState> {
  final StatusRepository _statusRepository;
  List<UserStatus> _cachedVibes = [];
  StreamSubscription? _statusSubscription;

  VibeBloc(this._statusRepository) : super(VibeInitial()) {
    on<LoadVibes>(_onLoadVibes);
    on<UploadVibe>(_onUploadVibe);
    on<DeleteVibe>(_onDeleteVibe);

    // Subscribe to real-time updates
    _statusSubscription = _statusRepository.watchStatusChanges().listen((_) {
      add(LoadVibes());
    });
  }

  @override
  Future<void> close() {
    _statusSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadVibes(LoadVibes event, Emitter<VibeState> emit) async {
    // Only show loading if we have no cached data yet to reduce UI jank
    if (_cachedVibes.isEmpty) {
      emit(VibeLoading());
    }

    try {
      final vibes = await _statusRepository.getActiveStatuses();
      _cachedVibes = vibes;
      emit(VibesLoaded(vibes));
    } catch (e) {
      // If we have cached vibes, keep showing them even on error
      if (_cachedVibes.isNotEmpty) {
        emit(VibesLoaded(_cachedVibes));
      } else {
        emit(VibeError(e.toString()));
      }
    }
  }

  Future<void> _onUploadVibe(UploadVibe event, Emitter<VibeState> emit) async {
    emit(VibeLoading());
    try {
      await _statusRepository.uploadStatus(event.file, event.isVideo,
          caption: event.caption);
      emit(VibeUploadSuccess());
      // No need to call LoadVibes here as the listener will handle it
    } catch (e) {
      emit(VibeError(e.toString()));
    }
  }

  Future<void> _onDeleteVibe(DeleteVibe event, Emitter<VibeState> emit) async {
    try {
      await _statusRepository.deleteStatus(event.statusId);
      // No need to call LoadVibes here as the listener will handle it
    } catch (e) {
      emit(VibeError(e.toString()));
    }
  }
}
