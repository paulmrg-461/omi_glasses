import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:omi_glasses/features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import 'package:omi_glasses/features/bluetooth/domain/entities/bluetooth_device_entity.dart';
import 'package:omi_glasses/features/settings/domain/repositories/settings_repository.dart';
import 'package:omi_glasses/features/settings/domain/entities/app_settings.dart';
import 'package:omi_glasses/features/vision/domain/repositories/vision_repository.dart';
import 'package:omi_glasses/features/audio/domain/repositories/audio_repository.dart';
import 'package:omi_glasses/features/memory/domain/repositories/memory_repository.dart';
import 'package:omi_glasses/features/memory/domain/entities/memory_entry.dart';
import 'package:omi_glasses/features/audio/domain/repositories/audio_repository.dart'
    as audiodomain;
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';
import 'package:omi_glasses/features/photo/domain/repositories/photo_repository.dart';
import 'package:omi_glasses/features/photo/domain/entities/photo_entry.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings _s = const AppSettings();
  @override
  Future<AppSettings> load() async {
    return _s;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _s = settings;
  }
}

class _FakeVisionRepository implements VisionRepository {
  @override
  Future<String> describeImage({
    required List<int> imageBytes,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    return 'ok';
  }
}

class _FakeAudioRepository implements AudioRepository {
  @override
  Future<String> transcribeAndSummarize({
    required Uint8List wavBytes,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    return 'resumen';
  }

  @override
  Future<List<String>> generateSuggestionsFromText({
    required String text,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    return ['Acción 1', 'Acción 2'];
  }
}

class _FakeAudioRepositoryStructured
    implements audiodomain.AudioRepositoryStructured {
  @override
  Future<audiodomain.TranscriptionResult> transcribeAndSummarizeStructured({
    required Uint8List wavBytes,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    return audiodomain.TranscriptionResult(
      transcript: 'texto',
      summary: 'resumen',
    );
  }
}

class _FakeMemoryRepository implements MemoryRepository {
  final List<MemoryEntry> store = [];
  @override
  Future<List<MemoryEntry>> list({int? limit}) async {
    return store;
  }

  @override
  Future<void> save(MemoryEntry entry) async {
    store.add(entry);
  }
}

class _FakePhotoRepository implements PhotoRepository {
  final List<PhotoEntry> store = [];
  @override
  Future<void> save(PhotoEntry entry) async {
    store.add(entry);
  }

  @override
  Future<List<PhotoEntry>> list({int? limit}) async {
    return store;
  }

  @override
  Future<void> clear() async {
    store.clear();
  }
}

void main() {
  late BluetoothViewModel viewModel;
  late MockBluetoothRepository mockRepository;
  late _FakeSettingsRepository fakeSettingsRepo;
  late _FakeVisionRepository fakeVisionRepo;
  late _FakeAudioRepository fakeAudioRepo;
  late _FakeMemoryRepository fakeMemoryRepo;
  late _FakeAudioRepositoryStructured fakeAudioRepoStructured;
  late _FakePhotoRepository fakePhotoRepo;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'requestPermissions') {
            return {
              Permission.bluetoothScan.value: PermissionStatus.granted.index,
              Permission.bluetoothConnect.value: PermissionStatus.granted.index,
              Permission.location.value: PermissionStatus.granted.index,
            };
          }
          return null;
        });

    mockRepository = MockBluetoothRepository();
    fakeSettingsRepo = _FakeSettingsRepository();
    fakeVisionRepo = _FakeVisionRepository();
    fakeAudioRepo = _FakeAudioRepository();
    fakeMemoryRepo = _FakeMemoryRepository();
    fakeAudioRepoStructured = _FakeAudioRepositoryStructured();
    fakePhotoRepo = _FakePhotoRepository();

    final getIt = GetIt.instance;
    if (!getIt.isRegistered<audiodomain.AudioRepositoryStructured>()) {
      getIt.registerSingleton<audiodomain.AudioRepositoryStructured>(
        fakeAudioRepoStructured,
      );
    }

    viewModel = BluetoothViewModel(
      repository: mockRepository,
      settingsRepository: fakeSettingsRepo,
      visionRepository: fakeVisionRepo,
      audioRepository: fakeAudioRepo,
      memoryRepository: fakeMemoryRepo,
      photoRepository: fakePhotoRepo,
    );
  });

  test('startScan calls repository.startScan', () async {
    when(() => mockRepository.startScan()).thenAnswer((_) async {});
    when(() => mockRepository.scanResults).thenAnswer((_) => Stream.value([]));

    await viewModel.startScan();

    verify(() => mockRepository.startScan()).called(1);
  });

  test('connect calls repository.connect and discoverServices', () async {
    const deviceId = 'test_device_id';
    when(() => mockRepository.connect(deviceId)).thenAnswer((_) async {});
    when(() => mockRepository.stopScan()).thenAnswer((_) async {});
    when(
      () => mockRepository.monitorBatteryLevel(deviceId),
    ).thenAnswer((_) => Stream.value(50));
    when(
      () => mockRepository.isPhotoCapable(deviceId),
    ).thenAnswer((_) async => false);
    when(
      () => mockRepository.startAudioStream(deviceId),
    ).thenAnswer((_) => Stream<Uint8List>.empty());
    when(
      () => mockRepository.stopAudioStream(deviceId),
    ).thenAnswer((_) async {});
    when(
      () => mockRepository.discoverServices(deviceId),
    ).thenAnswer((_) async => ['00001800-0000-1000-8000-00805f9b34fb']);

    await viewModel.connect(deviceId);

    verify(() => mockRepository.connect(deviceId)).called(1);
    verify(() => mockRepository.discoverServices(deviceId)).called(1);
    verifyNever(() => mockRepository.stopScan());
  });

  test(
    'autoReconnectFromSettings connects to audio device from settings',
    () async {
      const deviceId = 'audio_device_id';
      fakeSettingsRepo._s = const AppSettings(audioDeviceId: deviceId);

      when(() => mockRepository.startScan()).thenAnswer((_) async {});
      when(() => mockRepository.scanResults).thenAnswer(
        (_) => Stream.value([
          BluetoothDeviceEntity(
            id: deviceId,
            name: 'Device',
            rssi: -50,
            serviceUuids: const [],
          ),
        ]),
      );
      when(() => mockRepository.stopScan()).thenAnswer((_) async {});
      when(
        () => mockRepository.isBluetoothEnabled,
      ).thenAnswer((_) async => true);
      when(() => mockRepository.connect(deviceId)).thenAnswer((_) async {});
      when(
        () => mockRepository.discoverServices(deviceId),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.monitorBatteryLevel(deviceId),
      ).thenAnswer((_) => Stream<int>.empty());
      when(
        () => mockRepository.isPhotoCapable(deviceId),
      ).thenAnswer((_) async => false);
      when(
        () => mockRepository.startAudioStream(deviceId),
      ).thenAnswer((_) => Stream<Uint8List>.empty());
      when(
        () => mockRepository.stopAudioStream(deviceId),
      ).thenAnswer((_) async {});

      await viewModel.autoReconnectFromSettings();

      verify(() => mockRepository.startScan()).called(1);
      verify(() => mockRepository.connect(deviceId)).called(1);
    },
  );

  test(
    'autoReconnectFromSettings connects to both audio and photo devices when present',
    () async {
      const audioId = 'audio_device_id';
      const photoId = 'photo_device_id';
      fakeSettingsRepo._s = const AppSettings(
        audioDeviceId: audioId,
        photoDeviceId: photoId,
      );

      when(() => mockRepository.startScan()).thenAnswer((_) async {});
      when(() => mockRepository.scanResults).thenAnswer(
        (_) => Stream.value([
          BluetoothDeviceEntity(
            id: audioId,
            name: 'Audio',
            rssi: -40,
            serviceUuids: const [],
          ),
          BluetoothDeviceEntity(
            id: photoId,
            name: 'Photo',
            rssi: -45,
            serviceUuids: const [],
          ),
        ]),
      );
      when(() => mockRepository.stopScan()).thenAnswer((_) async {});
      when(
        () => mockRepository.isBluetoothEnabled,
      ).thenAnswer((_) async => true);

      when(() => mockRepository.connect(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.discoverServices(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.monitorBatteryLevel(any()),
      ).thenAnswer((_) => Stream<int>.empty());
      when(
        () => mockRepository.isPhotoCapable(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockRepository.startAudioStream(any()),
      ).thenAnswer((_) => Stream<Uint8List>.empty());
      when(
        () => mockRepository.stopAudioStream(any()),
      ).thenAnswer((_) async {});

      await viewModel.autoReconnectFromSettings();

      verify(() => mockRepository.startScan()).called(1);
      verify(() => mockRepository.connect(audioId)).called(1);
      verify(() => mockRepository.connect(photoId)).called(1);
    },
  );

  group('setupWifi', () {
    const deviceId = 'test_device_id';
    const ssid = 'ssid';
    const password = 'pass';

    setUp(() async {
      when(() => mockRepository.connect(deviceId)).thenAnswer((_) async {});
      when(
        () => mockRepository.discoverServices(deviceId),
      ).thenAnswer((_) async => []);
      when(
        () => mockRepository.monitorBatteryLevel(deviceId),
      ).thenAnswer((_) => Stream.value(50));
      when(
        () => mockRepository.isPhotoCapable(deviceId),
      ).thenAnswer((_) async => false);
      when(
        () => mockRepository.startAudioStream(deviceId),
      ).thenAnswer((_) => Stream<Uint8List>.empty());
      when(
        () => mockRepository.stopAudioStream(deviceId),
      ).thenAnswer((_) async {});
      await viewModel.connect(deviceId);
    });

    test('handles "Success" status correctly', () async {
      when(
        () => mockRepository.sendWifiCredentials(deviceId, ssid, password),
      ).thenAnswer((_) async {});

      when(
        () => mockRepository.listenForIpAddress(deviceId),
      ).thenAnswer((_) => Stream.value("Success"));

      await viewModel.setupWifi(ssid, password);

      expect(viewModel.statusMessage, contains("Accepted"));
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.cameraIp, isNull);
      expect(viewModel.isSettingUpWifi, false);
    });

    test('handles valid IP correctly', () async {
      when(
        () => mockRepository.sendWifiCredentials(deviceId, ssid, password),
      ).thenAnswer((_) async {});

      when(
        () => mockRepository.listenForIpAddress(deviceId),
      ).thenAnswer((_) => Stream.value("192.168.1.100"));

      await viewModel.setupWifi(ssid, password);

      expect(viewModel.cameraIp, "192.168.1.100");
      expect(viewModel.statusMessage, contains("IP: 192.168.1.100"));
      expect(viewModel.errorMessage, isNull);
    });

    test('handles Error string correctly', () async {
      when(
        () => mockRepository.sendWifiCredentials(deviceId, ssid, password),
      ).thenAnswer((_) async {});

      when(
        () => mockRepository.listenForIpAddress(deviceId),
      ).thenAnswer((_) => Stream.value("Error: 1"));

      await viewModel.setupWifi(ssid, password);

      expect(viewModel.errorMessage, contains("Wi-Fi Error: Error: 1"));
      expect(viewModel.cameraIp, isNull);
    });
  });
}
