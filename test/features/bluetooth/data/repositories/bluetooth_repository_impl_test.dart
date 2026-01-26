import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omi_glasses/features/bluetooth/data/datasources/bluetooth_remote_data_source.dart';
import 'package:omi_glasses/features/bluetooth/data/repositories/bluetooth_repository_impl.dart';
import 'package:omi_glasses/features/bluetooth/domain/entities/bluetooth_device_entity.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MockBluetoothRemoteDataSource extends Mock
    implements BluetoothRemoteDataSource {}

class MockBluetoothDevice extends Mock implements BluetoothDevice {}

class MockScanResult extends Mock implements ScanResult {}

void main() {
  late BluetoothRepositoryImpl repository;
  late MockBluetoothRemoteDataSource mockDataSource;

  setUp(() {
    mockDataSource = MockBluetoothRemoteDataSource();
    repository = BluetoothRepositoryImpl(dataSource: mockDataSource);
  });

  group('BluetoothRepositoryImpl', () {
    test('startScan calls dataSource.startScan', () async {
      when(
        () => mockDataSource.startScan(timeout: any(named: 'timeout')),
      ).thenAnswer((_) async {});

      await repository.startScan();

      verify(
        () => mockDataSource.startScan(timeout: any(named: 'timeout')),
      ).called(1);
    });

    test('stopScan calls dataSource.stopScan', () async {
      when(() => mockDataSource.stopScan()).thenAnswer((_) async {});

      await repository.stopScan();

      verify(() => mockDataSource.stopScan()).called(1);
    });

    // Note: Testing the stream transformation is complex due to ScanResult mocking structure
    // We will verify the interaction for now.
  });
}
