import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String username;
  final String fullName;

  AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.username,
    required this.fullName,
  });

  @override
  List<Object?> get props => [email, password, username, fullName];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  AuthSignInRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthProfileUpdateRequested extends AuthEvent {
  final String? fullName;
  final String? username;
  final String? age;
  final String? phone;
  final String? gender;
  final String? bio;
  final bool? isPublic;
  final XFile? avatarFile;

  AuthProfileUpdateRequested({
    this.fullName,
    this.username,
    this.age,
    this.phone,
    this.gender,
    this.bio,
    this.isPublic,
    this.avatarFile,
  });

  @override
  List<Object?> get props =>
      [fullName, username, age, phone, gender, bio, isPublic, avatarFile];
}
