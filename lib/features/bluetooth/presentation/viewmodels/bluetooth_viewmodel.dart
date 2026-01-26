import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';

class BluetoothViewModel extends ChangeNotifier {
  final BluetoothRepository repository;

  List<BluetoothDeviceEntity> _devices = [];
  List<BluetoothDeviceEntity> get devices => _devices;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  BluetoothDeviceEntity? _connectedDevice;
  BluetoothDeviceEntity? get connectedDevice => _connectedDevice;

  StreamSubscription? _scanSubscription;

  BluetoothViewModel({required this.repository});

  Future<void> startScan() async {
    _errorMessage = null;
    notifyListeners();

    // Request permissions
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    _isScanning = true;
    notifyListeners();

    // Cancel existing subscription if any
    await _scanSubscription?.cancel();

    _scanSubscription = repository.scanResults.listen((results) {
      _devices = results;
      notifyListeners();
    });

    await repository.startScan();
  }

  Future<void> stopScan() async {
    await repository.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> connect(String deviceId) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_isScanning) {
        await stopScan();
        // Wait for scan to fully stop to avoid HCI errors
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      // Add a timeout to the connection attempt (e.g., 30 seconds)
      await repository
          .connect(deviceId)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException(
                "Connection timed out. Device not found or not advertising.",
              );
            },
          );

      // If we get here, we are connected
      _connectedDevice = _devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => BluetoothDeviceEntity(
          id: deviceId,
          name: 'Unknown',
          rssi: 0,
          serviceUuids: [],
        ),
      );
      _errorMessage = null;
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      _errorMessage = e.toString();

      // Ensure we clean up any pending connection attempts
      try {
        await repository.disconnect(deviceId);
      } catch (_) {}

      // Notify UI of error state but don't crash
      if (e.toString().contains("255") ||
          e.toString().contains("UNKNOWN_HCI_ERROR")) {
        _errorMessage =
            "Android HCI 255 Error. Please restart Bluetooth on your phone.";
        debugPrint(
          "Known Android HCI 255 Error encountered. Please toggle Bluetooth.",
        );
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
