import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsState extends Equatable {
  final AppSettings settings;
  final bool loading;
  final String? error;
  const SettingsState({
    required this.settings,
    this.loading = false,
    this.error,
  });
  SettingsState copyWith({
    AppSettings? settings,
    bool? loading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [settings, loading, error];
}

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {}

class SetGeminiKey extends SettingsEvent {
  final String key;
  const SetGeminiKey(this.key);
}

class SetAudioDevice extends SettingsEvent {
  final String? deviceId;
  const SetAudioDevice(this.deviceId);
}

class SetPhotoDevice extends SettingsEvent {
  final String? deviceId;
  const SetPhotoDevice(this.deviceId);
}

class SetPhotoInterval extends SettingsEvent {
  final int seconds;
  const SetPhotoInterval(this.seconds);
}

class SetUseLocalModels extends SettingsEvent {
  final bool value;
  const SetUseLocalModels(this.value);
}

class SetLocalAudioUrl extends SettingsEvent {
  final String url;
  const SetLocalAudioUrl(this.url);
}

class SetLocalVisionUrl extends SettingsEvent {
  final String url;
  const SetLocalVisionUrl(this.url);
}

class PersistSettings extends SettingsEvent {}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository repository;
  SettingsBloc({required this.repository})
    : super(SettingsState(settings: const AppSettings())) {
    on<LoadSettings>(_onLoad);
    on<SetGeminiKey>(_onSetKey);
    on<SetAudioDevice>(_onSetAudio);
    on<SetPhotoDevice>(_onSetPhoto);
    on<SetPhotoInterval>(_onSetInterval);
    on<SetUseLocalModels>(_onSetUseLocal);
    on<SetLocalAudioUrl>(_onSetLocalAudioUrl);
    on<SetLocalVisionUrl>(_onSetLocalVisionUrl);
    on<PersistSettings>(_onPersist);
  }
  Future<void> _onLoad(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final s = await repository.load();
      emit(state.copyWith(settings: s, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void _onSetKey(SetGeminiKey event, Emitter<SettingsState> emit) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(geminiApiKey: event.key),
      ),
    );
  }

  void _onSetAudio(SetAudioDevice event, Emitter<SettingsState> emit) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(audioDeviceId: event.deviceId),
      ),
    );
  }

  void _onSetPhoto(SetPhotoDevice event, Emitter<SettingsState> emit) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(photoDeviceId: event.deviceId),
      ),
    );
  }

  void _onSetInterval(SetPhotoInterval event, Emitter<SettingsState> emit) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(photoIntervalSeconds: event.seconds),
      ),
    );
  }

  void _onSetUseLocal(SetUseLocalModels event, Emitter<SettingsState> emit) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(useLocalModels: event.value),
      ),
    );
  }

  void _onSetLocalAudioUrl(
    SetLocalAudioUrl event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(localAudioUrl: event.url),
      ),
    );
  }

  void _onSetLocalVisionUrl(
    SetLocalVisionUrl event,
    Emitter<SettingsState> emit,
  ) {
    emit(
      state.copyWith(
        settings: state.settings.copyWith(localVisionUrl: event.url),
      ),
    );
  }

  Future<void> _onPersist(
    PersistSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(loading: true, error: null));
    try {
      await repository.save(state.settings);
      emit(state.copyWith(loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
