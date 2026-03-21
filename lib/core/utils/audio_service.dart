import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioService {
  final _player = AudioPlayer();

  /// Plays the check-in beep if audio preference is enabled.
  Future<void> playBeep() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('pref_audio_beep') ?? true) {
      await _player.play(AssetSource('audio/beep.mp3'));
    }
  }

  /// Triggers haptic feedback if preference is enabled.
  Future<void> haptic() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('pref_haptic_feedback') ?? true) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 60);
      }
    }
  }

  /// Plays beep AND haptic together (called on successful check-in).
  Future<void> onCheckIn() async {
    await Future.wait([playBeep(), haptic()]);
  }

  void dispose() {
    _player.dispose();
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});
