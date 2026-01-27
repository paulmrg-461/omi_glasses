import 'dart:async';
import 'dart:typed_data';
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

  bool _isSettingUpWifi = false;
  bool get isSettingUpWifi => _isSettingUpWifi;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  BluetoothDeviceEntity? _connectedDevice;
  BluetoothDeviceEntity? get connectedDevice => _connectedDevice;

  List<String> _connectedDeviceServices = [];
  List<String> get connectedDeviceServices => _connectedDeviceServices;

  String? _cameraIp;
  String? get cameraIp => _cameraIp;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _ipSubscription;

  // Image Stream
  Stream<Uint8List>? _imageStream;
  Stream<Uint8List>? get imageStream => _imageStream;

  BluetoothViewModel({required this.repository});

  Future<void> startScan() async {
    _errorMessage = null;
    _statusMessage = null;
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
    _statusMessage = null;
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

      // Discover services to verify connection and capability
      try {
        _connectedDeviceServices = await repository.discoverServices(deviceId);
      } catch (e) {
        debugPrint("Error discovering services: $e");
        _connectedDeviceServices = ["Error discovering services: $e"];
      }

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

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      final deviceId = _connectedDevice!.id;
      _connectedDevice = null;
      _connectedDeviceServices = [];
      notifyListeners();
      await repository.disconnect(deviceId);
    }
  }

  Future<void> retryServiceDiscovery() async {
    if (_connectedDevice != null) {
      _connectedDeviceServices = await repository.discoverServices(
        _connectedDevice!.id,
      );
      notifyListeners();
    }
  }

  void startImageListener() {
    if (_connectedDevice == null) return;
    try {
      _imageStream = repository.listenToImages(_connectedDevice!.id);
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to start image listener: $e";
      notifyListeners();
    }
  }

  Future<void> triggerPhoto() async {
    if (_connectedDevice == null) return;
    try {
      await repository.triggerPhoto(_connectedDevice!.id);
      _statusMessage = "Photo triggered";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to trigger photo: $e";
      notifyListeners();
    }
  }

  Future<void> startVideo() async {
    if (_connectedDevice == null) return;
    try {
      await repository.startVideo(_connectedDevice!.id);
      _statusMessage = "Video started";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to start video: $e";
      notifyListeners();
    }
  }

  Future<void> setupWifi(String ssid, String password) async {
    if (_connectedDevice == null) return;

    _isSettingUpWifi = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      debugPrint("Starting Wi-Fi Setup for device: ${_connectedDevice!.id}");
      debugPrint("SSID: $ssid");

      // Cancel previous subscription if any
      _ipSubscription?.cancel();

      // Start listening for IP
      debugPrint("Subscribing to IP characteristic...");
      _ipSubscription = repository
          .listenForIpAddress(_connectedDevice!.id)
          .listen(
            (statusOrIp) {
              debugPrint("Received status/IP from glasses: $statusOrIp");

              if (statusOrIp == "Success") {
                // Wi-Fi connected, but no IP yet.
                // We can notify the user that credentials were accepted.
                _statusMessage = "Wi-Fi Credentials Accepted! connecting...";
                _errorMessage = null;
                // We don't set _cameraIp yet because "Success" is not an IP.
              } else if (statusOrIp.contains(".")) {
                // It looks like an IP address (basic check)
                _cameraIp = statusOrIp;
                _statusMessage = "Wi-Fi Connected! IP: $statusOrIp";
                _errorMessage = null; // Clear any status messages
              } else if (statusOrIp.startsWith("Error")) {
                _errorMessage = "Wi-Fi Error: $statusOrIp";
                _statusMessage = null;
              }

              _isSettingUpWifi = false;
              notifyListeners();
            },
            onError: (e) {
              debugPrint("Error receiving IP: $e");
              // Don't stop loading here, as this is a stream error, maybe transient
            },
          );

      // Send credentials
      debugPrint("Sending credentials...");
      await repository.sendWifiCredentials(
        _connectedDevice!.id,
        ssid,
        password,
      );
      debugPrint("Credentials sent successfully.");

      // Note: We keep _isSettingUpWifi = true until we get an IP or user cancels?
      // Actually, let's set it to false after sending, but keep the SnackBar telling user to wait.
      _isSettingUpWifi = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Setup Wi-Fi Failed: $e");
      _errorMessage = "Failed to send Wi-Fi credentials: $e";
      _isSettingUpWifi = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _ipSubscription?.cancel();
    super.dispose();
  }
}
