import '../entities/bluetooth_device_entity.dart';

abstract class BluetoothRepository {
  Stream<List<BluetoothDeviceEntity>> get scanResults;
  Future<void> startScan();
  Future<void> stopScan();
  Future<void> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Future<List<String>> discoverServices(String deviceId);
  Future<void> sendWifiCredentials(String deviceId, String ssid, String password);
  Stream<String> listenForIpAddress(String deviceId);
}
