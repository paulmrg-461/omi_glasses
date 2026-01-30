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

  // Audio features
  Stream<Uint8List> startAudioStream(String deviceId);
  Future<void> stopAudioStream(String deviceId);

  // Battery features
  Stream<int> monitorBatteryLevel(String deviceId);

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
