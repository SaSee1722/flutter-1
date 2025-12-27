import 'package:equatable/equatable.dart';
import '../../domain/entities/user_status.dart';

abstract class VibeState extends Equatable {
  const VibeState();

  @override
  List<Object?> get props => [];
}

class VibeInitial extends VibeState {}

class VibeLoading extends VibeState {}

class VibesLoaded extends VibeState {
  final List<UserStatus> vibes;

  const VibesLoaded(this.vibes);

  @override
  List<Object?> get props => [vibes];
}

class VibeUploadSuccess extends VibeState {}

class VibeError extends VibeState {
  final String message;

  const VibeError(this.message);

  @override
  List<Object?> get props => [message];
}
