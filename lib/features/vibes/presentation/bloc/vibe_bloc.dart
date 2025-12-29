import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/status_repository.dart';
import 'vibe_event.dart';
import 'vibe_state.dart';

class VibeBloc extends Bloc<VibeEvent, VibeState> {
  final StatusRepository _statusRepository;

  VibeBloc(this._statusRepository) : super(VibeInitial()) {
    on<LoadVibes>(_onLoadVibes);
    on<UploadVibe>(_onUploadVibe);
    on<DeleteVibe>(_onDeleteVibe);
  }

  Future<void> _onLoadVibes(LoadVibes event, Emitter<VibeState> emit) async {
    emit(VibeLoading());
    try {
      final vibes = await _statusRepository.getActiveStatuses();
      emit(VibesLoaded(vibes));
    } catch (e) {
      emit(VibeError(e.toString()));
    }
  }

  Future<void> _onUploadVibe(UploadVibe event, Emitter<VibeState> emit) async {
    emit(VibeLoading());
    try {
      await _statusRepository.uploadStatus(event.file, event.isVideo,
          caption: event.caption);
      emit(VibeUploadSuccess());
      add(LoadVibes());
    } catch (e) {
      emit(VibeError(e.toString()));
    }
  }

  Future<void> _onDeleteVibe(DeleteVibe event, Emitter<VibeState> emit) async {
    try {
      await _statusRepository.deleteStatus(event.statusId);
      add(LoadVibes());
    } catch (e) {
      emit(VibeError(e.toString()));
    }
  }
}
