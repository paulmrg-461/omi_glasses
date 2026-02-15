import 'package:get_it/get_it.dart';
import '../../features/bluetooth/data/datasources/bluetooth_remote_data_source.dart';
import '../../features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import '../../features/bluetooth/domain/repositories/bluetooth_repository.dart';
import '../../features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import '../../features/settings/data/datasources/settings_local_data_source.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';
import '../../features/vision/domain/repositories/vision_repository.dart';
import '../../features/vision/data/repositories/gemini_vision_repository.dart';
import '../../features/audio/domain/repositories/audio_repository.dart';
import '../../features/audio/data/repositories/gemini_audio_repository.dart';
import '../../features/memory/domain/repositories/memory_repository.dart';
import '../../features/memory/data/datasources/memory_local_data_source.dart';
import '../../features/memory/data/repositories/memory_repository_impl.dart';
import '../../features/audio/domain/repositories/audio_repository.dart' as audiodomain;

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Bluetooth
  // ViewModel
  sl.registerFactory(
    () => BluetoothViewModel(
      repository: sl(),
      settingsRepository: sl(),
      visionRepository: sl(),
      audioRepository: sl(),
      memoryRepository: sl(),
    ),
  );

  // Repository
  sl.registerLazySingleton<BluetoothRepository>(
    () => BluetoothRepositoryImpl(dataSource: sl()),
  );

  // Data Source
  sl.registerLazySingleton<BluetoothRemoteDataSource>(
    () => BluetoothRemoteDataSourceImpl(),
  );

  // Settings
  sl.registerLazySingleton<SettingsLocalDataSource>(
    () => SettingsLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(local: sl()),
  );
  sl.registerFactory(() => SettingsBloc(repository: sl()));

  // Vision
  sl.registerLazySingleton<VisionRepository>(() => GeminiVisionRepository());

  // Audio
  sl.registerLazySingleton<AudioRepository>(() => GeminiAudioRepository());
  sl.registerLazySingleton<audiodomain.AudioRepositoryStructured>(
    () => GeminiAudioRepositoryStructured(),
  );

  // Memory
  sl.registerLazySingleton<MemoryLocalDataSource>(
    () => MemoryLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<MemoryRepository>(
    () => MemoryRepositoryImpl(local: sl()),
  );
  await sl<MemoryLocalDataSource>().init();
}
