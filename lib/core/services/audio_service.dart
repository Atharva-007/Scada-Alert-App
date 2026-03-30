import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AlertSound { critical, warning, info, none }

class AudioService {
  bool _isMuted = false;
  bool _vibrationEnabled = true;

  bool get isMuted => _isMuted;
  bool get vibrationEnabled => _vibrationEnabled;

  void setMuted(bool muted) {
    _isMuted = muted;
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
  }

  Future<void> playAlertSound(String severity) async {
    if (_isMuted) return;

    final sound = _getSoundForSeverity(severity);

    switch (sound) {
      case AlertSound.critical:
        await _playCriticalSound();
        break;
      case AlertSound.warning:
        await _playWarningSound();
        break;
      case AlertSound.info:
        await _playInfoSound();
        break;
      case AlertSound.none:
        break;
    }

    if (_vibrationEnabled) {
      await _vibrate(severity);
    }
  }

  AlertSound _getSoundForSeverity(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return AlertSound.critical;
      case 'warning':
        return AlertSound.warning;
      case 'info':
        return AlertSound.info;
      default:
        return AlertSound.none;
    }
  }

  Future<void> _playCriticalSound() async {
    // Use platform channel for system alert sound
    await HapticFeedback.heavyImpact();
    // TODO: Add actual audio file playback when assets are added
  }

  Future<void> _playWarningSound() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> _playInfoSound() async {
    await HapticFeedback.lightImpact();
  }

  Future<void> _vibrate(String severity) async {
    switch (severity.toLowerCase()) {
      case 'critical':
        // Long vibration pattern for critical
        await HapticFeedback.heavyImpact();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        break;
      case 'warning':
        await HapticFeedback.mediumImpact();
        break;
      case 'info':
        await HapticFeedback.lightImpact();
        break;
    }
  }

  Future<void> testSound(AlertSound sound) async {
    switch (sound) {
      case AlertSound.critical:
        await _playCriticalSound();
        break;
      case AlertSound.warning:
        await _playWarningSound();
        break;
      case AlertSound.info:
        await _playInfoSound();
        break;
      case AlertSound.none:
        break;
    }
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});
