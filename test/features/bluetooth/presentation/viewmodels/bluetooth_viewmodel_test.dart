import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/domain/repositories/bluetooth_repository.dart';
import 'package:omi_glasses/features/bluetooth/presentation/viewmodels/bluetooth_viewmodel.dart';
import 'package:omi_glasses/features/bluetooth/domain/entities/bluetooth_device_entity.dart';
import 'package:permission_handler/permission_handler.dart';

class MockBluetoothRepository extends Mock implements BluetoothRepository {}

void main() {
  late BluetoothViewModel viewModel;
  late MockBluetoothRepository mockRepository;

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
    viewModel = BluetoothViewModel(repository: mockRepository);
  });

  test('startScan calls repository.startScan', () async {
    when(() => mockRepository.startScan()).thenAnswer((_) async {});
    when(() => mockRepository.scanResults).thenAnswer((_) => Stream.value([]));

    await viewModel.startScan();

    verify(() => mockRepository.startScan()).called(1);
  });

  test('connect calls repository.connect', () async {
    const deviceId = 'test_device_id';
    when(() => mockRepository.connect(deviceId)).thenAnswer((_) async {});
    when(() => mockRepository.stopScan()).thenAnswer((_) async {});

    // Simulate scanning state if we want to test stopScan
    // But initially isScanning is false, so it should just call connect
    await viewModel.connect(deviceId);

    verify(() => mockRepository.connect(deviceId)).called(1);
    verifyNever(() => mockRepository.stopScan());
  });
}
