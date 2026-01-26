import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothRemoteDataSource {
  Stream<List<ScanResult>> get scanResults;
  Future<void> startScan({Duration? timeout});
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device);
  Future<void> disconnect(BluetoothDevice device);
}

class BluetoothRemoteDataSourceImpl implements BluetoothRemoteDataSource {
  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Future<void> startScan({Duration? timeout}) {
    return FlutterBluePlus.startScan(timeout: timeout);
  }

  @override
  Future<void> stopScan() {
    return FlutterBluePlus.stopScan();
  }

  @override
  Future<void> connect(BluetoothDevice device) {
    return device.connect(autoConnect: false);
  }

  @override
  Future<void> disconnect(BluetoothDevice device) {
    return device.disconnect();
  }
}
