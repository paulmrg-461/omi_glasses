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

  /// Monitors ALL services and characteristics for debugging purposes.
  /// Returns a stream of log strings with UUIDs and data.
  Stream<String> monitorAllServices(String deviceId);

  /// Writes bytes to a characteristic.
  Future<void> writeCharacteristicBytes(
    String deviceId,
    String serviceUuid,
    String charUuid,
    List<int> value,
  );

  /// Reads bytes from a characteristic.
  Future<List<int>> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String charUuid,
  );

  /// Checks if the device has a specific service UUID.
  Future<bool> hasService(String deviceId, String serviceUuid);

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
