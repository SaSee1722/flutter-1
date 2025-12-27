import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';

class MediaUploadHelper {
  static Future<Message> uploadMedia({
    required Uint8List bytes,
    required String fileName,
    required String roomId,
    required String bucket,
    required String mediaType,
    required String contentPrefix,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Upload to Supabase Storage
    final fileExt = fileName.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '$userId/$timestamp.$fileExt';

    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinary(storagePath, bytes);

    // Get public URL
    final publicUrl =
        Supabase.instance.client.storage.from(bucket).getPublicUrl(storagePath);

    // Create message
    return Message(
      id: '',
      roomId: roomId,
      userId: userId,
      content: contentPrefix,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      mediaUrl: publicUrl,
      mediaType: mediaType,
      mediaName: fileName,
      mediaSize: bytes.length,
    );
  }
}
