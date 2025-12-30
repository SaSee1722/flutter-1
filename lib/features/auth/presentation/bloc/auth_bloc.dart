import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/features/auth/domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:gossip/core/notifications/notification_service.dart';
import 'package:gossip/core/di/injection_container.dart' as di;
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final ChatRepository _chatRepository;

  AuthBloc(this._authRepository, this._chatRepository) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthProfileUpdateRequested>(_onAuthProfileUpdateRequested);
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final user = _authRepository.currentUser;
    if (user != null) {
      _chatRepository.setOnlineStatus(true);
      di.sl<NotificationService>().uploadTokenToSupabase();
      emit(AuthAuthenticated(user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signUp(
        email: event.email,
        password: event.password,
        username: event.username,
        fullName: event.fullName,
      );
      final user = _authRepository.currentUser;
      if (user != null) {
        di.sl<NotificationService>().uploadTokenToSupabase();
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authRepository.signIn(
        email: event.email,
        password: event.password,
      );
      final user = _authRepository.currentUser;
      if (user != null) {
        di.sl<NotificationService>().uploadTokenToSupabase();
        _chatRepository.setOnlineStatus(true);
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _chatRepository.setOnlineStatus(false);
    await _authRepository.signOut();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthProfileUpdateRequested(
    AuthProfileUpdateRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      emit(AuthLoading());
      try {
        if (event.avatarFile != null) {
          await _authRepository.updateAvatar(event.avatarFile!);
        }

        // Only update profile if there are actual profile changes
        if (event.fullName != null ||
            event.username != null ||
            event.age != null ||
            event.phone != null ||
            event.gender != null ||
            event.bio != null ||
            event.isPublic != null) {
          await _authRepository.updateProfile(
            fullName: event.fullName,
            username: event.username,
            age: event.age,
            phone: event.phone,
            gender: event.gender,
            bio: event.bio,
            isPublic: event.isPublic,
          );
        }
        emit(AuthAuthenticated(_authRepository.currentUser!));
      } catch (e) {
        emit(AuthFailure(e.toString()));
        emit(AuthAuthenticated(currentState.user));
      }
    }
  }
}
