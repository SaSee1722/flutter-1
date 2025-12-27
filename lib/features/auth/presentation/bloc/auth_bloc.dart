import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/features/auth/domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
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
        await _authRepository.updateProfile(
          fullName: event.fullName,
          username: event.username,
          age: event.age,
          phone: event.phone,
          gender: event.gender,
          bio: event.bio,
        );
        emit(AuthAuthenticated(_authRepository.currentUser!));
      } catch (e) {
        emit(AuthFailure(e.toString()));
        emit(AuthAuthenticated(currentState.user));
      }
    }
  }
}
