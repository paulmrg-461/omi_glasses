import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String? geminiApiKey;
  final String? audioDeviceId;
  final String? photoDeviceId;
  final int photoIntervalSeconds;
  final bool useLocalModels;
  final String? localApiBaseUrl;
  const AppSettings({
    this.geminiApiKey,
    this.audioDeviceId,
    this.photoDeviceId,
    this.photoIntervalSeconds = 60,
    this.useLocalModels = false,
    this.localApiBaseUrl,
  });
  AppSettings copyWith({
    String? geminiApiKey,
    String? audioDeviceId,
    String? photoDeviceId,
    int? photoIntervalSeconds,
    bool? useLocalModels,
    String? localApiBaseUrl,
  }) {
    return AppSettings(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      photoDeviceId: photoDeviceId ?? this.photoDeviceId,
      photoIntervalSeconds: photoIntervalSeconds ?? this.photoIntervalSeconds,
      useLocalModels: useLocalModels ?? this.useLocalModels,
      localApiBaseUrl: localApiBaseUrl ?? this.localApiBaseUrl,
    );
  }
  @override
  List<Object?> get props => [
        geminiApiKey,
        audioDeviceId,
        photoDeviceId,
        photoIntervalSeconds,
        useLocalModels,
        localApiBaseUrl,
      ];
}
