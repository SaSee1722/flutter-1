import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class CallSoundService {
  final AudioPlayer _player = AudioPlayer();

  // Call States
  static const String ringingSound = 'sounds/call_ringing.mp3';
  static const String connectedSound = 'sounds/call_connected.mp3';
  static const String endedSound = 'sounds/call_ended.mp3';

  CallSoundService() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playRinging() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      // Assumes assets/sounds/call_ringing.mp3 exists
      await _player.play(AssetSource(ringingSound));
    } catch (e) {
      debugPrint("Error playing ringing sound: $e");
    }
  }

  Future<void> playConnected() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource(connectedSound));
    } catch (e) {
      debugPrint("Error playing connected sound: $e");
    }
  }

  Future<void> playEnded() async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.play(AssetSource(endedSound));
    } catch (e) {
      debugPrint("Error playing ended sound: $e");
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint("Error stopping sound: $e");
    }
  }
}
