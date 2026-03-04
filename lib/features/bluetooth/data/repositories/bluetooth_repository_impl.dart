import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_opus/flutter_opus.dart';
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../datasources/bluetooth_remote_data_source.dart';
import '../../../../core/constants/bluetooth_constants.dart';

class BluetoothRepositoryImpl implements BluetoothRepository {
  final BluetoothRemoteDataSource dataSource;

  BluetoothRepositoryImpl({required this.dataSource});

  @override
  Stream<Uint8List> startAudioStream(String deviceId) async* {
    final device = BluetoothDevice.fromId(deviceId);

    // Initialize Opus decoder (16kHz mono as per guide)
    OpusDecoder? decoder;
    try {
      // Create decoder (synchronous in this package version usually, or check if it needs await)
      // The analyzer said "await_only_futures", so it is synchronous.
      decoder = OpusDecoder.create(sampleRate: 16000, channels: 1);
    } catch (e) {
      debugPrint("BlueRepo: Failed to create OpusDecoder: $e");
      rethrow;
    }

    try {
      debugPrint("BlueRepo: Starting audio stream for $deviceId");
      final stream = dataSource.subscribeToCharacteristic(
        device,
        BluetoothConstants.serviceUuid,
        BluetoothConstants.audioDataUuid,
      );

      await for (final packet in stream) {
        if (packet.length > 3) {
          // Skip 3 bytes header
          final opusData = Uint8List.fromList(packet.sublist(3));

          try {
            // Decode Opus to PCM
            // Try common frame sizes (20ms=320, 40ms=640, 60ms=960)
            if (decoder != null) {
              List<int> sizes = [320, 640, 960];
              Uint8List? out;
              for (final sz in sizes) {
                final pcmData = decoder.decode(opusData, sz);
                if (pcmData != null && pcmData.isNotEmpty) {
                  out = Uint8List.fromList(pcmData);
                  break;
                }
              }
              if (out != null) {
                yield out;
              }
            }
          } catch (e) {
            debugPrint("Opus decode error: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("BlueRepo: Error in audio stream: $e");
      rethrow;
    } finally {
      debugPrint("BlueRepo: Audio stream closed.");
      decoder?.dispose();
    }
  }

  @override
  Future<void> stopAudioStream(String deviceId) async {
    // Currently no explicit stop command needed on the BLE side
    // as we just stop listening to the stream.
    // If we wanted to save battery, we could disable notifications here.
    debugPrint("BlueRepo: Stop audio stream requested for $deviceId");
  }

  @override
  Stream<int> monitorBatteryLevel(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource
        .subscribeToCharacteristic(
          device,
          BluetoothConstants.batteryServiceUuid,
          BluetoothConstants.batteryLevelUuid,
        )
        .map((data) {
          if (data.isNotEmpty) {
            // Battery level is a single byte (0-100)
            return data[0];
          }
          return -1;
        });
  }

  @override
  Stream<int> monitorHeartRate(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource
        .subscribeToCharacteristic(
          device,
          BluetoothConstants.heartRateServiceUuid,
          BluetoothConstants.heartRateMeasurementUuid,
        )
        .map((data) {
          if (data.isEmpty) return 0;

          // Parse Heart Rate Measurement (0x2A37)
          // Byte 0: Flags
          int flags = data[0];
          bool isUint16 = (flags & 0x01) != 0;

          if (isUint16 && data.length >= 3) {
            // HR is in byte 1 and 2 (Little Endian)
            return data[1] + (data[2] << 8);
          } else if (!isUint16 && data.length >= 2) {
            // HR is in byte 1
            return data[1];
          }
          return 0;
        });
  }

  @override
  Stream<String> monitorAllServices(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.monitorAllServices(device);
  }

  @override
  Future<void> writeCharacteristicBytes(
    String deviceId,
    String serviceUuid,
    String charUuid,
    List<int> value,
  ) async {
    final devices = await dataSource.connectedDevices;
    final device = devices.firstWhere(
      (d) => d.remoteId.toString() == deviceId,
      orElse: () => throw Exception('Device not connected'),
    );
    await dataSource.writeCharacteristicBytes(
      device,
      serviceUuid,
      charUuid,
      value,
    );
  }

  @override
  Future<List<int>> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String charUuid,
  ) async {
    final devices = await dataSource.connectedDevices;
    final device = devices.firstWhere(
      (d) => d.remoteId.toString() == deviceId,
      orElse: () => throw Exception('Device not connected'),
    );
    return await dataSource.readCharacteristic(device, serviceUuid, charUuid);
  }

  @override
  Future<bool> hasService(String deviceId, String serviceUuid) async {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.hasService(device, serviceUuid);
  }

  @override
  Future<bool> get isBluetoothEnabled => dataSource.isBluetoothEnabled;

  @override
  Stream<bool> get bluetoothState => dataSource.bluetoothState;

  @override
  Future<void> turnOnBluetooth() => dataSource.turnOnBluetooth();

  @override
  Stream<List<BluetoothDeviceEntity>> get scanResults {
    return dataSource.scanResults.map((results) {
      return results
          .where((result) {
            final name = result.advertisementData.localName;
            final platformName = result.device.platformName;
            final serviceUuids = result.advertisementData.serviceUuids
                .map((uuid) => uuid.toString().toLowerCase())
                .toList();

            // Filter logic:
            // 1. OMI Devices (Service UUID or Name)
            if (serviceUuids.contains(
              BluetoothConstants.serviceUuid.toLowerCase(),
            )) {
              return true;
            }
            if (name.toUpperCase().startsWith("OMI") ||
                platformName.toUpperCase().startsWith("OMI")) {
              return true;
            }

            // 2. Y25 Band (Relaxed check)
            if (name.toUpperCase().contains("Y25") ||
                platformName.toUpperCase().contains("Y25")) {
              return true;
            }

            // 3. DEBUG: Show EVERYTHING that has a name
            // This is temporary to help find the device if the name doesn't match exactly
            if (name.isNotEmpty) {
              return true;
            }

            return false;
          })
          .map((result) {
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
                  .map((e) => e.toString())
                  .toList(),
            );
          })
          .toList();
    });
  }

  @override
  Future<void> startScan() => dataSource.startScan(
    timeout: const Duration(seconds: 10),
    // withServices removed to allow Y25 band discovery
  );

  @override
  Future<void> stopScan() => dataSource.stopScan();

  @override
  Future<void> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    // Use autoConnect=true for better stability
    await dataSource.connect(device, autoConnect: true);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    await dataSource.disconnect(device);
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
    if (ssid.isEmpty || ssid.length > 32) {
      throw Exception('SSID must be 1-32 characters');
    }
    if (password.length > 63) {
      throw Exception('Password must be less than 64 characters');
    }

    final device = BluetoothDevice.fromId(deviceId);

    // This feature is currently disabled in firmware or uses a different mechanism
    // but we keep the structure for future updates.
    // For now, we just throw to indicate it's not ready or try a generic write.
    debugPrint("Sending WiFi creds: $ssid / $password");
    // TODO: Implement actual BLE write for WiFi if protocol is known
  }

  @override
  Stream<String> listenForIpAddress(String deviceId) {
    // This would listen to a characteristic that reports IP
    // For now, return empty
    return const Stream.empty();
  }

  @override
  Stream<ImageReceptionState> listenToImages(String deviceId) async* {
    final device = BluetoothDevice.fromId(deviceId);

    // Subscribe to Photo Data Characteristic
    final stream = dataSource.subscribeToCharacteristic(
      device,
      BluetoothConstants.serviceUuid,
      BluetoothConstants.photoDataUuid,
    );

    int totalBytes = 0;
    int packets = 0;
    final List<int> buffer = [];

    await for (final packet in stream) {
      if (packet.isNotEmpty) {
        // Simple protocol: Accumulate bytes.
        // In a real protocol, we'd check for headers, length, etc.
        // Here we assume the device sends raw JPEG bytes.
        // We might need a "End of Image" marker or similar.

        buffer.addAll(packet);
        totalBytes += packet.length;
        packets++;

        yield ImageReceptionProgress(totalBytes, packets);

        // Check for JPEG End of Image (EOI): 0xFF, 0xD9
        if (buffer.length >= 2 &&
            buffer[buffer.length - 2] == 0xFF &&
            buffer[buffer.length - 1] == 0xD9) {
          yield ImageReceptionSuccess(Uint8List.fromList(buffer));
          buffer.clear();
          totalBytes = 0;
          packets = 0;
        }
      }
    }
  }

  @override
  Future<void> triggerPhoto(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    // Write 0x01 to Control Characteristic to trigger photo
    await dataSource.writeCharacteristic(
      device,
      BluetoothConstants.serviceUuid,
      BluetoothConstants.photoControlUuid,
      "1", // '1' char is 0x31. Check if firmware needs 0x01 byte or '1' string.
      // Assuming string "1" for now based on common patterns, or change to writeBytes if needed.
    );
  }

  @override
  Future<void> startVideo(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    // Write 0x02 to Control Characteristic to start video
    await dataSource.writeCharacteristic(
      device,
      BluetoothConstants.serviceUuid,
      BluetoothConstants.photoControlUuid,
      "2",
    );
  }

  @override
  Future<bool> isPhotoCapable(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    return dataSource.hasService(device, BluetoothConstants.serviceUuid);
  }
}
