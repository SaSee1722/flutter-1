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
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // 1. Fetch accepted friend IDs
    final friendsData = await _supabase
        .from('friend_requests')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');

    final List<String> allowedIds = [user.id];
    for (var item in (friendsData as List)) {
      if (item['sender_id'] == user.id) {
        allowedIds.add(item['receiver_id']);
      } else {
        allowedIds.add(item['sender_id']);
      }
    }

    // 2. Fetch statuses ONLY from these IDs, joined with status_views for current user
    final response = await _supabase
        .from('statuses')
        .select('*, profiles(*), status_views!left(viewer_id)')
        .inFilter('user_id', allowedIds)
        .eq('status_views.viewer_id',
            user.id) // Only join views by current user
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (response as List).map((json) => UserStatus.fromJson(json)).toList();
  }

  @override
  Future<void> deleteStatus(String statusId) async {
    await _supabase.from('statuses').delete().eq('id', statusId);
  }

  @override
  Future<void> markStatusViewed(String statusId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Record specific view in status_views table
      await _supabase.from('status_views').upsert({
        'status_id': statusId,
        'viewer_id': user.id,
      });

      // 2. Increment total view_count in statuses table
      final data = await _supabase
          .from('statuses')
          .select('view_count, user_id')
          .eq('id', statusId)
          .maybeSingle();

      if (data != null && data['user_id'] != user.id) {
        final currentCount = data['view_count'] ?? 0;
        await _supabase
            .from('statuses')
            .update({'view_count': currentCount + 1}).eq('id', statusId);
      }
    } catch (e) {
      debugPrint('Error marking status as viewed: $e');
    }
  }
}
