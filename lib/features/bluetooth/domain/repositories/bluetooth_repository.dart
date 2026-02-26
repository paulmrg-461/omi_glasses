import 'dart:typed_data';
import '../entities/bluetooth_device_entity.dart';

abstract class BluetoothRepository {
  Stream<List<BluetoothDeviceEntity>> get scanResults;
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Future<List<String>> discoverServices(String deviceId);
  Future<void> sendWifiCredentials(
    String deviceId,
    String ssid,
    String password,
  );
  Stream<String> listenForIpAddress(String deviceId);

  // New features based on OMI Guide
  Stream<ImageReceptionState> listenToImages(String deviceId);
  Future<void> triggerPhoto(String deviceId);
  Future<void> startVideo(String deviceId);
  Future<bool> isPhotoCapable(String deviceId);

  // Audio features
  Stream<Uint8List> startAudioStream(String deviceId);
  Future<void> stopAudioStream(String deviceId);

  // Battery features
  /// Monitors the battery level of the connected device.
  /// Returns a stream of battery level percentage (0-100).
  Stream<int> monitorBatteryLevel(String deviceId);

  /// Monitors the heart rate of the connected device (if supported).
  /// Returns a stream of heart rate in BPM.
  Stream<int> monitorHeartRate(String deviceId);

  // Bluetooth State
  Future<bool> get isBluetoothEnabled;
  Stream<bool> get bluetoothState;
  Future<void> turnOnBluetooth();
}

abstract class ImageReceptionState {}

class ImageReceptionProgress extends ImageReceptionState {
  final int bytesReceived;
  final int packetsReceived;
  ImageReceptionProgress(this.bytesReceived, this.packetsReceived);
}

class ImageReceptionSuccess extends ImageReceptionState {
  final Uint8List imageBytes;
  ImageReceptionSuccess(this.imageBytes);
}

class ImageReceptionError extends ImageReceptionState {
  final String error;
  ImageReceptionError(this.error);
}
