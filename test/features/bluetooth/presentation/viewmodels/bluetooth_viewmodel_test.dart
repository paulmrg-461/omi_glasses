import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:omi_glasses/features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import 'package:omi_glasses/features/bluetooth/domain/entities/bluetooth_device_entity.dart';
import 'package:omi_glasses/features/settings/domain/repositories/settings_repository.dart';
import 'package:omi_glasses/features/settings/domain/entities/app_settings.dart';
import 'package:omi_glasses/features/vision/domain/repositories/vision_repository.dart';
import 'package:permission_handler/permission_handler.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late BluetoothViewModel viewModel;
  late MockBluetoothRepository mockRepository;
  // Minimal fake settings & vision repos to satisfy constructor
  late _FakeSettingsRepository fakeSettingsRepo;
  late _FakeVisionRepository fakeVisionRepo;

  class _FakeSettingsRepository implements SettingsRepository {
    AppSettings _s = const AppSettings();
    @override
    Future<void> persist(AppSettings s) async {
      _s = s;
    }
    @override
    Future<AppSettings> load() async {
      return _s;
    }
  }
  class _FakeVisionRepository implements VisionRepository {
    @override
    Future<String> describeImage({required List<int> imageBytes, required String apiKey, String model = 'gemini-1.5-flash'}) async {
      return 'ok';
    }
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock Permission Handler Channel
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
    viewModel = BluetoothViewModel(
      repository: mockRepository,
      settingsRepository: fakeSettingsRepo,
      visionRepository: fakeVisionRepo,
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
      () => mockRepository.discoverServices(deviceId),
    ).thenAnswer((_) async => ['00001800-0000-1000-8000-00805f9b34fb']);

    // Simulate scanning state if we want to test stopScan
    // But initially isScanning is false, so it should just call connect
    await viewModel.connect(deviceId);

    verify(() => mockRepository.connect(deviceId)).called(1);
    verify(() => mockRepository.discoverServices(deviceId)).called(1);
    verifyNever(() => mockRepository.stopScan());
  });

  group('setupWifi', () {
    const deviceId = 'test_device_id';
    const ssid = 'ssid';
    const password = 'pass';

    setUp(() async {
      // Establish a connection first
      when(() => mockRepository.connect(deviceId)).thenAnswer((_) async {});
      when(
        () => mockRepository.discoverServices(deviceId),
      ).thenAnswer((_) async => []);
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
