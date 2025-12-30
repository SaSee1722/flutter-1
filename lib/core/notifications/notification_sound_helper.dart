import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationSoundHelper {
  static const String _defaultSoundKey = 'default_notification_sound';
  static const String _defaultSoundTitleKey =
      'default_notification_sound_title';
  static const String _chatSoundPrefix = 'notification_sound_';
  static const String _chatSoundTitlePrefix = 'notification_sound_title_';

  static const MethodChannel _channel =
      MethodChannel('com.gossip/ringtone_picker');

  /// Picks a system notification sound using Android's RingtoneManager
  /// Returns true if a sound was selected, false otherwise
  static Future<bool> pickSystemNotificationSound({String? chatId}) async {
    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('pickNotificationSound');

      if (result != null) {
        final uri = result['uri'] as String?;
        final title = result['title'] as String?;

        if (uri != null && title != null) {
          final prefs = await SharedPreferences.getInstance();

          if (chatId != null) {
            // Save for specific chat
            await prefs.setString('$_chatSoundPrefix$chatId', uri);
            await prefs.setString('$_chatSoundTitlePrefix$chatId', title);
          } else {
            // Save as default
            await prefs.setString(_defaultSoundKey, uri);
            await prefs.setString(_defaultSoundTitleKey, title);
          }

          debugPrint('Saved notification sound: $title ($uri)');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error picking notification sound: $e');
    }
    return false;
  }

  /// Picks a system ringtone using Android's RingtoneManager
  static Future<bool> pickSystemRingtone() async {
    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>('pickRingtone');

      if (result != null) {
        final uri = result['uri'] as String?;
        final title = result['title'] as String?;

        if (uri != null && title != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('call_ringtone', uri);
          await prefs.setString('call_ringtone_title', title);

          debugPrint('Saved ringtone: $title ($uri)');
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error picking ringtone: $e');
    }
    return false;
  }

  /// Retrieves the saved sound path/URI for a chat, falling back to default
  static Future<String?> getSoundPath({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try Chat specific
    if (chatId != null) {
      final chatSound = prefs.getString('$_chatSoundPrefix$chatId');
      if (chatSound != null) {
        return chatSound;
      }
    }

    // 2. Try Global default
    final defaultSound = prefs.getString(_defaultSoundKey);
    if (defaultSound != null) {
      return defaultSound;
    }

    return null; // Fallback to system default
  }

  /// Gets the title of the saved notification sound
  static Future<String?> getSoundTitle({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (chatId != null) {
      final title = prefs.getString('$_chatSoundTitlePrefix$chatId');
      if (title != null) return title;
    }

    return prefs.getString(_defaultSoundTitleKey);
  }

  /// Gets the title of the saved ringtone
  static Future<String?> getRingtoneTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('call_ringtone_title');
  }

  /// Clears a custom sound for a chat or default
  static Future<void> clearCustomSound({String? chatId}) async {
    final prefs = await SharedPreferences.getInstance();

    if (chatId != null) {
      await prefs.remove('$_chatSoundPrefix$chatId');
      await prefs.remove('$_chatSoundTitlePrefix$chatId');
    } else {
      await prefs.remove(_defaultSoundKey);
      await prefs.remove(_defaultSoundTitleKey);
    }
  }

  /// Clears the custom ringtone
  static Future<void> clearCustomRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('call_ringtone');
    await prefs.remove('call_ringtone_title');
  }
}
