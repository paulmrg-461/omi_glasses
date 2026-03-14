import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String? geminiApiKey;
  final String? audioDeviceId;
  final String? photoDeviceId;
  final String? healthDeviceId;
  final int photoIntervalSeconds;
  final bool useLocalModels;
  final String? localAudioUrl;
  final String? localVisionUrl;

  const AppSettings({
    this.geminiApiKey,
    this.audioDeviceId,
    this.photoDeviceId,
    this.healthDeviceId,
    this.photoIntervalSeconds = 60,
    this.useLocalModels = false,
    this.localAudioUrl,
    this.localVisionUrl,
  });

  AppSettings copyWith({
    String? geminiApiKey,
    String? audioDeviceId,
    String? photoDeviceId,
    String? healthDeviceId,
    int? photoIntervalSeconds,
    bool? useLocalModels,
    String? localAudioUrl,
    String? localVisionUrl,
  }) {
    return AppSettings(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      photoDeviceId: photoDeviceId ?? this.photoDeviceId,
      healthDeviceId: healthDeviceId ?? this.healthDeviceId,
      photoIntervalSeconds: photoIntervalSeconds ?? this.photoIntervalSeconds,
      useLocalModels: useLocalModels ?? this.useLocalModels,
      localAudioUrl: localAudioUrl ?? this.localAudioUrl,
      localVisionUrl: localVisionUrl ?? this.localVisionUrl,
    );
  }

  @override
  List<Object?> get props => [
    geminiApiKey,
    audioDeviceId,
    photoDeviceId,
    healthDeviceId,
    photoIntervalSeconds,
    useLocalModels,
    localAudioUrl,
    localVisionUrl,
  ];
}
