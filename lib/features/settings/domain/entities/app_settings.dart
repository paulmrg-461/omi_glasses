import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final String? geminiApiKey;
  final String? audioDeviceId;
  final String? photoDeviceId;
  final int photoIntervalSeconds;
  final bool useLocalModels;
  final String? localAudioUrl;
  final String? localVisionUrl;

  const AppSettings({
    this.geminiApiKey,
    this.audioDeviceId,
    this.photoDeviceId,
    this.photoIntervalSeconds = 60,
    this.useLocalModels = false,
    this.localAudioUrl,
    this.localVisionUrl,
  });

  AppSettings copyWith({
    String? geminiApiKey,
    String? audioDeviceId,
    String? photoDeviceId,
    int? photoIntervalSeconds,
    bool? useLocalModels,
    String? localAudioUrl,
    String? localVisionUrl,
  }) {
    return AppSettings(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      audioDeviceId: audioDeviceId ?? this.audioDeviceId,
      photoDeviceId: photoDeviceId ?? this.photoDeviceId,
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
    photoIntervalSeconds,
    useLocalModels,
    localAudioUrl,
    localVisionUrl,
  ];
}
