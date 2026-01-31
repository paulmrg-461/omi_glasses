import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/data/datasources/bluetooth_remote_data_source.dart';
import 'package:omi_glasses/features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import 'package:omi_glasses/features/bluetooth/domain/entities/bluetooth_device_entity.dart';
import 'package:omi_glasses/core/constants/bluetooth_constants.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MockBluetoothRemoteDataSource extends Mock
    implements BluetoothRemoteDataSource {}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockScanResult extends Mock implements ScanResult {}

class MockAdvertisementData extends Mock implements AdvertisementData {}

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

      test(
        'should write SSID and Password to respective characteristics',
        () async {
          // Arrange
          when(
            () =>
                mockDataSource.writeCharacteristic(any(), any(), any(), any()),
          ).thenAnswer((_) async {});

          // Act
          await repository.sendWifiCredentials(deviceId, ssid, password);

          // Assert
          // Verify SSID write
          verify(
            () => mockDataSource.writeCharacteristic(
              any(that: isA<BluetoothDevice>()),
              BluetoothConstants.serviceUuid,
              BluetoothConstants.wifiSsidUuid,
              ssid,
            ),
          ).called(1);

          // Verify Password write
          verify(
            () => mockDataSource.writeCharacteristic(
              any(that: isA<BluetoothDevice>()),
              BluetoothConstants.serviceUuid,
              BluetoothConstants.wifiPasswordUuid,
              password,
            ),
          ).called(1);
        },
      );
    });

    group('listenForIpAddress', () {
      const deviceId = 'test_device_id';
      const ipAddress = '192.168.1.100';

      test('should return IP address stream', () async {
        // Arrange
        when(
          () => mockDataSource.subscribeToCharacteristic(any(), any(), any()),
        ).thenAnswer((_) => Stream.value(ipAddress.codeUnits));

        // Act
        final stream = repository.listenForIpAddress(deviceId);

        // Assert
        expect(stream, emits(ipAddress));
        verify(
          () => mockDataSource.subscribeToCharacteristic(
            any(that: isA<BluetoothDevice>()),
            BluetoothConstants.serviceUuid,
            BluetoothConstants.ipAddressUuid,
          ),
        ).called(1);
      });
    });

    group('scanResults', () {
      test('filters by UUID and correctly names nameless OMI device', () {
        // Arrange
        final mockResult = MockScanResult();
        final mockDevice = MockBluetoothDevice();
        final mockAdData = MockAdvertisementData();

        when(() => mockResult.device).thenReturn(mockDevice);
        when(() => mockResult.advertisementData).thenReturn(mockAdData);
        when(() => mockResult.rssi).thenReturn(-50);

        when(
          () => mockDevice.remoteId,
        ).thenReturn(const DeviceIdentifier('id1'));
        when(() => mockDevice.platformName).thenReturn(''); // Nameless

        when(() => mockAdData.localName).thenReturn('');
        when(
          () => mockAdData.serviceUuids,
        ).thenReturn([Guid(BluetoothConstants.serviceUuid)]); // Has OMI UUID
        when(() => mockAdData.manufacturerData).thenReturn({});

        when(
          () => mockDataSource.scanResults,
        ).thenAnswer((_) => Stream.value([mockResult]));

        // Act
        final stream = repository.scanResults;

        // Assert
        expect(
          stream,
          emits(
            predicate<List<BluetoothDeviceEntity>>((list) {
              return list.length == 1 &&
                  list.first.name == 'OmiGlass' && // Autocomplete check (Updated)
                  list.first.id == 'id1';
            }),
          ),
        );
      });

      test('filters out non-OMI devices only if weak signal', () {
        // Arrange
        final mockResult = MockScanResult();
        final mockDevice = MockBluetoothDevice();
        final mockAdData = MockAdvertisementData();

        when(() => mockResult.device).thenReturn(mockDevice);
        when(() => mockResult.advertisementData).thenReturn(mockAdData);
        when(() => mockResult.rssi).thenReturn(-99); // WEAK SIGNAL

        when(
          () => mockDevice.remoteId,
        ).thenReturn(const DeviceIdentifier('id2'));
        when(() => mockDevice.platformName).thenReturn('Some Device');

        when(() => mockAdData.localName).thenReturn('');
        when(() => mockAdData.serviceUuids).thenReturn([]); // No OMI UUID
        when(() => mockAdData.manufacturerData).thenReturn({});

        when(
          () => mockDataSource.scanResults,
        ).thenAnswer((_) => Stream.value([mockResult]));

        // Act
        final stream = repository.scanResults;

        // Assert
        expect(
          stream,
          emits(
            predicate<List<BluetoothDeviceEntity>>((list) {
              return list.isEmpty;
            }),
          ),
        );
      });
    });
  });
}
