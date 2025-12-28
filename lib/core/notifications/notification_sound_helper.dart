import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class NotificationSoundHelper {
  static const String _defaultSoundKey = 'default_notification_sound';
  static const String _chatSoundPrefix = 'notification_sound_';

  /// Picks an audio file and saves it as the custom sound for a specific chat
  /// or as the default sound if chatId is null.
  static Future<bool> setCustomSound({String? chatId}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final File originalFile = File(result.files.single.path!);
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String soundDir = path.join(appDir.path, 'notification_sounds');

        // Ensure directory exists
        await Directory(soundDir).create(recursive: true);

        final String fileName =
            '${chatId ?? "default"}_${path.basename(originalFile.path)}';
        final String savedPath = path.join(soundDir, fileName);

        // Copy file to local storage
        await originalFile.copy(savedPath);

        // Save preference
        final prefs = await SharedPreferences.getInstance();
        final key =
            chatId != null ? '$_chatSoundPrefix$chatId' : _defaultSoundKey;
        await prefs.setString(key, savedPath);

        debugPrint('Saved custom sound to: $savedPath');
        return true;
      }
    } catch (e) {
      debugPrint('Error setting custom sound: $e');
    }
    return false;
  }

  /// Retrieves the saved sound path for a chat, falling back to default app sound.
  static Future<String?> getSoundPath({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try Chat specific
    if (chatId != null) {
      final chatSound = prefs.getString('$_chatSoundPrefix$chatId');
      if (chatSound != null && await File(chatSound).exists()) {
        return chatSound;
      }
    }

    // 2. Try Global default
    final defaultSound = prefs.getString(_defaultSoundKey);
    if (defaultSound != null && await File(defaultSound).exists()) {
      return defaultSound;
    }

    return null; // Fallback to system default
  }

  /// Clears a custom sound for a chat or default.
  static Future<void> clearCustomSound({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = chatId != null ? '$_chatSoundPrefix$chatId' : _defaultSoundKey;
    final existingPath = prefs.getString(key);

    if (existingPath != null) {
      final file = File(existingPath);
      if (await file.exists()) {
        await file.delete();
      }
      await prefs.remove(key);
    }
  }
}
