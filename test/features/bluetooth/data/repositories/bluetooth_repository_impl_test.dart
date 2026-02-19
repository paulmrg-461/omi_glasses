import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/data/datasources/bluetooth_remote_data_source.dart';
import 'package:omi_glasses/features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import 'package:omi_glasses/core/constants/bluetooth_constants.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MockBluetoothRemoteDataSource extends Mock
    implements BluetoothRemoteDataSource {}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockScanResult extends Mock implements ScanResult {}

void main() {
  late BluetoothRepositoryImpl repository;
  late MockBluetoothRemoteDataSource mockDataSource;

  setUpAll(() {
    registerFallbackValue(MockBluetoothDevice());
  });

  setUp(() {
    mockDataSource = MockBluetoothRemoteDataSource();
    repository = BluetoothRepositoryImpl(dataSource: mockDataSource);
  });

  group('BluetoothRepositoryImpl', () {
    test('startScan calls dataSource.startScan', () async {
      when(
        () => mockDataSource.startScan(
          timeout: any(named: 'timeout'),
          withServices: any(named: 'withServices'),
        ),
      ).thenAnswer((_) async {});

      await repository.startScan();

      verify(
        () => mockDataSource.startScan(
          timeout: any(named: 'timeout'),
          withServices: any(named: 'withServices'),
        ),
      ).called(1);
    });

    test('stopScan calls dataSource.stopScan', () async {
      when(() => mockDataSource.stopScan()).thenAnswer((_) async {});

      await repository.stopScan();

      verify(() => mockDataSource.stopScan()).called(1);
    });

    group('sendWifiCredentials', () {
      const deviceId = 'test_device_id';
      const ssid = 'test_ssid';
      const password = 'test_password';

      test('should send correct packets when service exists', () async {
        // Arrange
        when(
          () => mockDataSource.writeCharacteristicBytes(
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenAnswer((_) async {});

        // Act
        await repository.sendWifiCredentials(deviceId, ssid, password);

        // Assert
        // Verify first packet (Credentials)
        verify(
          () => mockDataSource.writeCharacteristicBytes(
            any(that: isA<BluetoothDevice>()),
            BluetoothConstants.wifiServiceUuid,
            BluetoothConstants.wifiCharacteristicUuid,
            any(
              that: predicate<List<int>>((bytes) {
                // Basic check: starts with 0x01
                return bytes[0] == 0x01;
              }),
            ),
          ),
        ).called(1);

        // Verify second packet (Start command)
        verify(
          () => mockDataSource.writeCharacteristicBytes(
            any(that: isA<BluetoothDevice>()),
            BluetoothConstants.wifiServiceUuid,
            BluetoothConstants.wifiCharacteristicUuid,
            [0x02],
          ),
        ).called(1);
      });

      test(
        'should throw user-friendly exception when service not found',
        () async {
          // Arrange
          when(
            () => mockDataSource.writeCharacteristicBytes(
              any(),
              any(),
              any(),
              any(),
            ),
          ).thenThrow(Exception('Service 3029... not found'));

          // Act & Assert
          expect(
            () => repository.sendWifiCredentials(deviceId, ssid, password),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'This OMI device (Glasses) does not support',
                ),
              ),
            ),
          );
        },
      );

      test('should throw exception for invalid SSID length', () async {
        expect(
          () => repository.sendWifiCredentials(deviceId, '', password),
          throwsException,
        );
      });

      test('should throw exception for invalid Password length', () async {
        expect(
          () => repository.sendWifiCredentials(deviceId, ssid, 'short'),
          throwsException,
        );
      });
    });
  });
}
