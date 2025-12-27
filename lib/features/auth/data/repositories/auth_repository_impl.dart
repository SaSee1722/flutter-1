import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/auth/domain/repositories/auth_repository.dart';
import 'package:gossip/core/constants/supabase_constants.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'full_name': fullName,
      },
    );
    return response;
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Future<void> updateProfile({
    String? fullName,
    String? username,
    String? age,
    String? phone,
    String? gender,
    String? bio,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final updates = {
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (fullName != null) updates['full_name'] = fullName;
    if (username != null) updates['username'] = username;
    if (age != null) updates['age'] = age;
    if (phone != null) updates['phone'] = phone;
    if (gender != null) updates['gender'] = gender;
    if (bio != null) updates['bio'] = bio;

    await _supabase
        .from(SupabaseConstants.profilesTable)
        .update(updates)
        .eq('id', user.id);
  }

  @override
  Future<String?> updateAvatar(XFile imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.name.split('.').last;
    final fileName =
        '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from(SupabaseConstants.avatarsBucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    final avatarUrl = _supabase.storage
        .from(SupabaseConstants.avatarsBucket)
        .getPublicUrl(fileName);

    await _supabase.from(SupabaseConstants.profilesTable).update({
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    return avatarUrl;
  }

  @override
  Session? get currentSession => _supabase.auth.currentSession;

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
