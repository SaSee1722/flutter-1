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
    // We join status_views but we DON'T filter at top level to keep unviewed ones visible.
    final response = await _supabase
        .from('statuses')
        .select('*, profiles(*), status_views(viewer_id)')
        .inFilter('user_id', allowedIds)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);

    // Map and filter views in Dart to check isViewed accurately
    return (response as List).map((json) {
      final views = (json['status_views'] as List?) ?? [];
      final hasViewed = views.any((v) => v['viewer_id'] == user.id);

      // Inject the computed viewed status into the JSON for the entity factory
      final mappedJson = Map<String, dynamic>.from(json);
      mappedJson['is_viewed_by_me'] = hasViewed;

      return UserStatus.fromJson(mappedJson);
    }).toList();
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
      // Check if we already viewed this to avoid redundant calls
      // The database trigger will handle the increment only on the FIRST view (Insert).
      await _supabase.from('status_views').upsert({
        'status_id': statusId,
        'viewer_id': user.id,
      }, onConflict: 'status_id, viewer_id');

      debugPrint('Marked status $statusId as viewed by ${user.id}');
    } catch (e) {
      debugPrint('Error marking status as viewed: $e');
    }
  }

  @override
  Stream<void> watchStatusChanges() {
    return _supabase.from('statuses').stream(primaryKey: ['id']).map((_) {});
  }
}
