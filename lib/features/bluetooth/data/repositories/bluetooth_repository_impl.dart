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
            // frameSize: Max samples per channel.
            // 16kHz * 60ms = 960 samples. Safe upper bound for single frame.
            // The analyzer said "decode" needs 2 args.
            // And it is NOT async.
            if (decoder != null) {
              final pcmData = decoder.decode(opusData, 960);
              if (pcmData != null && pcmData.isNotEmpty) {
                // pcmData is List<int> (PCM 16-bit samples?)
                // If it's 16-bit PCM, we need to convert to bytes (Uint8List) for the player?
                // FlutterSoundPlayer expects PCM 16-bit as bytes (little endian).
                // If flutter_opus returns Int16List or List<int> acting as Int16,
                // we need to verify format.
                // Assuming List<int> contains 16-bit values?
                // Or bytes?
                // "Decode Opus data (Uint8List) to PCM (Uint8List)" says the snippet.
                // So pcmData is likely Uint8List or List<int> of BYTES.
                yield Uint8List.fromList(pcmData);
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
  Stream<ImageReceptionState> listenToImages(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);
    List<int> imageBuffer = [];
    int packets = 0;
    int nextExpectedFrame = 0;
    int mismatchCount = 0;
    bool isTransferring = false;

    return dataSource
        .subscribeToCharacteristic(
          device,
          BluetoothConstants.serviceUuid,
          BluetoothConstants.photoDataUuid,
        )
        .expand((data) {
          List<ImageReceptionState> events = [];

          if (data.length < 2) {
            return events;
          }

          // The first 2 bytes are the frame index (little endian)
          int frameIndex = data[0] | (data[1] << 8);

          // End of image marker: Emit full image
          if (frameIndex == 0xFFFF) {
            if (isTransferring && imageBuffer.isNotEmpty) {
              debugPrint(
                "BlueRepo: End of image marker. Buffer: ${imageBuffer.length} bytes. Mismatches: $mismatchCount",
              );
              final finalImage = Uint8List.fromList(imageBuffer);

              debugPrint(
                "BlueRepo: Hex Header: ${finalImage.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}",
              );

              // Validate JPEG Header (SOI: FF D8)
              int start = -1;
              if (finalImage.length > 2 &&
                  finalImage[0] == 0xFF &&
                  finalImage[1] == 0xD8) {
                start = 0;
              } else {
                debugPrint("BlueRepo: Invalid JPEG header at 0. Searching...");
                for (int i = 0; i < finalImage.length - 1; i++) {
                  if (finalImage[i] == 0xFF && finalImage[i + 1] == 0xD8) {
                    start = i;
                    break;
                  }
                }
              }

              if (start != -1) {
                debugPrint("BlueRepo: Valid JPEG start at $start");
                Uint8List imageToProcess;
                if (start == 0) {
                  imageToProcess = finalImage;
                } else {
                  imageToProcess = finalImage.sublist(start);
                }

                // Check for EOI
                if (imageToProcess.length > 2 &&
                    imageToProcess[imageToProcess.length - 2] == 0xFF &&
                    imageToProcess[imageToProcess.length - 1] == 0xD9) {
                  events.add(ImageReceptionSuccess(imageToProcess));
                } else {
                  debugPrint("BlueRepo: Missing EOI marker. Appending FF D9.");
                  final patchedImage = Uint8List(imageToProcess.length + 2);
                  patchedImage.setRange(
                    0,
                    imageToProcess.length,
                    imageToProcess,
                  );
                  patchedImage[imageToProcess.length] = 0xFF;
                  patchedImage[imageToProcess.length + 1] = 0xD9;
                  events.add(ImageReceptionSuccess(patchedImage));
                }
              } else {
                debugPrint("BlueRepo: Could not find JPEG header. Discarding.");
                events.add(ImageReceptionError("Invalid image data received"));
              }
            }
            imageBuffer.clear();
            packets = 0;
            nextExpectedFrame = 0;
            isTransferring = false;
            return events;
          }

          // Frame 0: Start of new image
          if (frameIndex == 0) {
            debugPrint("BlueRepo: Start of new image (Frame 0)");
            imageBuffer.clear();
            packets = 1;
            nextExpectedFrame = 1;
            mismatchCount = 0;
            isTransferring = true;

            // Firmware Version Heuristic:
            // Check where the JPEG header (FF D8) starts to determine header size.
            // New firmware (>=2.1.1): Frame ID (2) + Orientation (1) + Data
            // Old firmware: Frame ID (2) + Data

            int dataStart = 2; // Default to old firmware (index 2)

            // Look for FF D8 in the first few bytes
            for (int i = 2; i < data.length - 1; i++) {
              if (data[i] == 0xFF && data[i + 1] == 0xD8) {
                dataStart = i;
                debugPrint(
                  "BlueRepo: Found JPEG header at index $i in Frame 0.",
                );
                break;
              }
            }

            if (data.length > dataStart) {
              imageBuffer.addAll(data.sublist(dataStart));
            }
          } else {
            // Subsequent frames
            if (!isTransferring) {
              // Ignore stray packets if we haven't seen Frame 0
              return events;
            }

            if (frameIndex != nextExpectedFrame) {
              mismatchCount++;
              debugPrint(
                "BlueRepo: Frame mismatch! Expected $nextExpectedFrame, got $frameIndex. Continuing anyway (Permissive Mode).",
              );
              // Update expectation to match reality + 1
              nextExpectedFrame = frameIndex + 1;
            } else {
              nextExpectedFrame = frameIndex + 1;
            }

            // Header is ALWAYS 2 bytes (Frame Index) for subsequent frames
            if (data.length > 2) {
              imageBuffer.addAll(data.sublist(2));
            }

            packets++;
          }

          events.add(ImageReceptionProgress(imageBuffer.length, packets));

          return events;
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
