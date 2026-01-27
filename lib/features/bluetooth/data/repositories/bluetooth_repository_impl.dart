import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../datasources/bluetooth_remote_data_source.dart';
import '../../../../core/constants/bluetooth_constants.dart';

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
    // We scan for OMI devices specifically, but also allow general scanning if needed.
    // For now, let's include the OMI Service UUID to prioritize finding the glasses.
    return dataSource.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [BluetoothConstants.serviceUuid],
    );
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

  @override
  Future<void> sendWifiCredentials(
    String deviceId,
    String ssid,
    String password,
  ) async {
    final device = BluetoothDevice.fromId(deviceId);

    // Construct packet: [cmd(1), ssid_len, ssid..., pass_len, pass...]
    final ssidBytes = utf8.encode(ssid);
    final passBytes = utf8.encode(password);

    if (ssidBytes.isEmpty || ssidBytes.length > 32) {
      throw Exception("Invalid SSID length (max 32)");
    }
    if (passBytes.length < 8 || passBytes.length > 64) {
      throw Exception("Invalid Password length (min 8, max 64)");
    }

    List<int> packet = [];
    packet.add(0x01); // WIFI_SETUP command
    packet.add(ssidBytes.length);
    packet.addAll(ssidBytes);
    packet.add(passBytes.length);
    packet.addAll(passBytes);

    try {
      await dataSource.writeCharacteristicBytes(
        device,
        BluetoothConstants.wifiServiceUuid, // Wi-Fi Service (Necklace only)
        BluetoothConstants.wifiCharacteristicUuid,
        packet,
      );

      // Send WIFI_START (0x02) to trigger connection
      await Future.delayed(const Duration(milliseconds: 500));
      await dataSource.writeCharacteristicBytes(
        device,
        BluetoothConstants.wifiServiceUuid,
        BluetoothConstants.wifiCharacteristicUuid,
        [0x02], // WIFI_START command
      );
    } catch (e) {
      if (e.toString().contains("Service") &&
          e.toString().contains("not found")) {
        throw Exception(
          "This OMI device (Glasses) does not support Wi-Fi configuration via Bluetooth. Please ensure you are using a compatible firmware version.",
        );
      }
      throw e;
    }
  }

  @override
  Stream<String> listenForIpAddress(String deviceId) {
    // Current firmware doesn't expose IP via BLE directly yet.
    // It notifies status codes on the wifi characteristic.
    // 0 = success, other = error.
    final device = BluetoothDevice.fromId(deviceId);

    try {
      return dataSource
          .subscribeToCharacteristic(
            device,
            BluetoothConstants.wifiServiceUuid,
            BluetoothConstants.wifiCharacteristicUuid,
          )
          .map((bytes) {
            if (bytes.isNotEmpty) {
              // 0x00 means success
              if (bytes[0] == 0) return "Success";
              return "Error: ${bytes[0]}";
            }
            return "";
          });
    } catch (e) {
      // Return empty stream or error if service not found
      return Stream.error(
        "Wi-Fi status monitoring not supported on this device.",
      );
    }
  }

  @override
  Stream<Uint8List> listenToImages(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    List<int> imageBuffer = [];

    return dataSource
        .subscribeToCharacteristic(
          device,
          BluetoothConstants.serviceUuid,
          BluetoothConstants.photoDataUuid,
        )
        .expand((data) {
          if (data.length < 2) return [];

          // The first 2 bytes are the frame index (little endian)
          int frameIndex = data[0] | (data[1] << 8);

          if (frameIndex == 0xFFFF) {
            // End of image marker: Emit full image
            if (imageBuffer.isNotEmpty) {
              final finalImage = Uint8List.fromList(imageBuffer);
              imageBuffer.clear();
              return [finalImage];
            }
          } else {
            // Append data to buffer (skip header)
            if (data.length > 2) {
              imageBuffer.addAll(data.sublist(2));
            }
          }
          return [];
        });
  }

  @override
  Future<void> triggerPhoto(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await dataSource.writeCharacteristicBytes(
      device,
      BluetoothConstants.serviceUuid,
      BluetoothConstants.photoControlUuid,
      [0xFF], // Command for single photo (as per guide)
    );
  }

  @override
  Future<void> startVideo(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    // Command for continuous capture (e.g. 1 frame per second)
    // Guide says 0x01 is for 1s interval? Let's use that.
    await dataSource.writeCharacteristicBytes(
      device,
      BluetoothConstants.serviceUuid,
      BluetoothConstants.photoControlUuid,
      [0x01],
    );
  }
}
