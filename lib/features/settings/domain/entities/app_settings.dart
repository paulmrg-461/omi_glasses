import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String? geminiApiKey;
  final String? audioDeviceId;
  final String? photoDeviceId;
  final int photoIntervalSeconds;
  const AppSettings({
    this.geminiApiKey,
    this.audioDeviceId,
    this.photoDeviceId,
    this.photoIntervalSeconds = 60,
  });
  AppSettings copyWith({
    String? geminiApiKey,
    String? audioDeviceId,
    String? photoDeviceId,
    int? photoIntervalSeconds,
  }) {
    return AppSettings(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      photoDeviceId: photoDeviceId ?? this.photoDeviceId,
      photoIntervalSeconds: photoIntervalSeconds ?? this.photoIntervalSeconds,
    );
  }
  @override
  List<Object?> get props => [
        geminiApiKey,
        audioDeviceId,
        photoDeviceId,
        photoIntervalSeconds,
      ];
}
