import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:image_picker/image_picker.dart';

abstract class AuthRepository {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? age,
    String? phone,
    String? gender,
    String? bio,
  });

  Future<String?> updateAvatar(XFile imageFile);

  Session? get currentSession;
  User? get currentUser;
  Stream<AuthState> get authStateChanges;
}
