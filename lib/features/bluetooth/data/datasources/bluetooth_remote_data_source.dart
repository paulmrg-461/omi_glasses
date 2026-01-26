import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothRemoteDataSource {
  Stream<List<ScanResult>> get scanResults;
  Future<void> startScan({Duration? timeout});
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device);
  Future<void> disconnect(BluetoothDevice device);
  Future<List<String>> discoverServices(BluetoothDevice device);
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

  @override
  Future<List<String>> discoverServices(BluetoothDevice device) async {
    // Wait a bit after connection before discovering services
    // This is often needed on Android to allow the GATT stack to settle
    await Future.delayed(const Duration(milliseconds: 2000));

    try {
      debugPrint("Discovering services for ${device.remoteId}...");
      List<BluetoothService> services = await device.discoverServices();
      
      if (services.isEmpty) {
        debugPrint("No services found. Retrying discovery in 2 seconds...");
        await Future.delayed(const Duration(seconds: 2));
        services = await device.discoverServices();
      }

      debugPrint("Found ${services.length} services.");
      return services.map((s) => s.uuid.toString()).toList();
    } catch (e) {
      debugPrint("Error discovering services: $e");
      // Try one more time after a longer delay
       await Future.delayed(const Duration(seconds: 3));
       try {
         final services = await device.discoverServices();
         return services.map((s) => s.uuid.toString()).toList();
       } catch (e2) {
         debugPrint("Retry failed: $e2");
         return [];
       }
    }
  }
}
