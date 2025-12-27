import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gossip/features/vibes/domain/entities/user_status.dart';
import 'package:gossip/features/vibes/domain/repositories/status_repository.dart';

class SupabaseStatusRepository implements StatusRepository {
  final SupabaseClient _supabase;

  SupabaseStatusRepository(this._supabase);

  @override
  Future<void> uploadStatus(XFile file, bool isVideo, {String? caption}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final fileExt = file.name.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = '${user.id}/$fileName';

    final bytes = await file.readAsBytes();
    await _supabase.storage.from('vibe-media').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    // ...
    final mediaUrl =
        _supabase.storage.from('vibe-media').getPublicUrl(filePath);

    await _supabase.from('statuses').insert({
      'user_id': user.id,
      'media_url': mediaUrl,
      'caption': caption,
      'is_video': isVideo,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    });
    debugPrint('Status uploaded successfully: $filePath');
  }

  @override
  Future<List<UserStatus>> getActiveStatuses() async {
    final response = await _supabase
        .from('statuses')
        .select('*, profiles(*)')
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('created_at', ascending: false);

    return (response as List).map((json) => UserStatus.fromJson(json)).toList();
  }

  @override
  Future<void> deleteStatus(String statusId) async {
    await _supabase.from('statuses').delete().eq('id', statusId);
  }
}
