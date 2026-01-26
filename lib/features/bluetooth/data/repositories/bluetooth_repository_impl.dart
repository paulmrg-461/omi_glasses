import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../datasources/bluetooth_remote_data_source.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final BluetoothRemoteDataSource dataSource;

  BluetoothRepositoryImpl({required this.dataSource});

  @override
  Stream<List<BluetoothDeviceEntity>> get scanResults {
    return dataSource.scanResults.map((results) {
      return results.map((result) {
        final localName = result.advertisementData.localName;
        final platformName = result.device.platformName;

        final name = localName.isNotEmpty
            ? localName
            : (platformName.isNotEmpty ? platformName : 'Unknown Device');

        return BluetoothDeviceEntity(
          id: result.device.remoteId.toString(),
          name: name,
          rssi: result.rssi,
          serviceUuids: result.advertisementData.serviceUuids
              .map((uuid) => uuid.toString())
              .toList(),
        );
      }).toList();
    });
  }

  @override
  Future<void> startScan() async {
    return dataSource.startScan(timeout: const Duration(seconds: 15));
  }

  @override
  Future<void> stopScan() async {
    return dataSource.stopScan();
  }

  @override
  Future<void> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.connect(device);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.disconnect(device);
  }

  @override
  Future<List<String>> discoverServices(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.discoverServices(device);
  }
}
