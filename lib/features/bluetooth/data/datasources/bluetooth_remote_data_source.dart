import 'package:flutter/foundation.dart';
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
  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (e) {
      // Ignore error if already disconnected
    }

    // Force delay to ensure GATT is fully cleared
    await Future.delayed(const Duration(milliseconds: 200));

    // ALWAYS use autoConnect: true for this device to avoid HCI 255
    // This hands off the connection timing to the Android OS
    debugPrint("Connecting with autoConnect: true to avoid HCI 255...");
    await device.connect(
      autoConnect: true,
      mtu: null, // REQUIRED for autoConnect: true
    );
    
    // Once connected, we can try to request a higher MTU if needed, 
    // but usually we just want the connection first.
  }

  @override
  Future<void> disconnect(BluetoothDevice device) {
    return device.disconnect();
  }
}
