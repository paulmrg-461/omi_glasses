import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/app_settings.dart';

abstract class SettingsLocalDataSource {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  static const String kGeminiKey = 'gemini_api_key';
  static const String kAudioDeviceId = 'audio_device_id';
  static const String kPhotoDeviceId = 'photo_device_id';
  static const String kPhotoInterval = 'photo_interval_seconds';
  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(kGeminiKey);
    final audioId = prefs.getString(kAudioDeviceId);
    final photoId = prefs.getString(kPhotoDeviceId);
    final interval = prefs.getInt(kPhotoInterval) ?? 60;
    return AppSettings(
      geminiApiKey: key,
      audioDeviceId: audioId,
      photoDeviceId: photoId,
      photoIntervalSeconds: interval,
    );
  }
  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.geminiApiKey != null) {
      await prefs.setString(kGeminiKey, settings.geminiApiKey!);
    }
    if (settings.audioDeviceId != null) {
      await prefs.setString(kAudioDeviceId, settings.audioDeviceId!);
    }
    if (settings.photoDeviceId != null) {
      await prefs.setString(kPhotoDeviceId, settings.photoDeviceId!);
    }
    await prefs.setInt(kPhotoInterval, settings.photoIntervalSeconds);
  }
}
