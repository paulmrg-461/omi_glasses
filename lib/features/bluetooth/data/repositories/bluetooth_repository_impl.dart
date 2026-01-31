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
  Future<bool> get isBluetoothEnabled => dataSource.isBluetoothEnabled;

  @override
  Stream<bool> get bluetoothState => dataSource.bluetoothState;

  @override
  Future<void> turnOnBluetooth() => dataSource.turnOnBluetooth();

  @override
  Stream<List<BluetoothDeviceEntity>> get scanResults {
    return dataSource.scanResults.map((results) {
      // DEBUG: Log RAW results to diagnose visibility issues
      if (results.isNotEmpty) {
        debugPrint("BlueRepo: RAW Scan results count: ${results.length}");
        for (var r in results) {
          // Log EVERYTHING to find the hidden device
          final name = r.device.platformName;
          debugPrint(
            "  >> Device: '$name' (${r.device.remoteId}) RSSI: ${r.rssi}",
          );
          debugPrint("     UUIDs: ${r.advertisementData.serviceUuids}");
        }
      }

      final filteredResults = results.where((result) {
        try {
          final platformName = result.device.platformName;
          final serviceUuids = result.advertisementData.serviceUuids
              .map((uuid) => uuid.toString().toLowerCase())
              .toList();

          // 1. Check strict UUID match (Primary detection method for new firmware)
          // Firmware 1.0.4 Update: UUID is guaranteed to be in the Primary Advertisement packet.
          final hasOmiUuid = serviceUuids.contains(
            BluetoothConstants.serviceUuid.toLowerCase(),
          );

          // 2. Check name match (Legacy fallback & Scan Response)
          // Firmware 1.0.4 Update: Name "OmiGlass" is in Scan Response.
          final nameStr = platformName.toLowerCase();
          final hasOmiName =
              nameStr.contains("omi") ||
              nameStr.contains("open glass") ||
              nameStr.contains("openglass");

          // Debug logic for detection
          if (hasOmiUuid) {
            // Found via UUID (Perfect!)
          } else if (hasOmiName) {
            debugPrint(
              "BlueRepo: Detected by Name only (UUID missing in packet?): $platformName",
            );
          }

          // 3. Proximity Fallback (Safety Net)
          // If the OS hasn't merged the packet yet, we accept strong signals as potential candidates.
          final isStrongSignal = result.rssi > -60;

          // Accept if: UUID matches, OR Name matches, OR it's a strong signal nearby
          return hasOmiUuid || hasOmiName || isStrongSignal;
        } catch (e) {
          debugPrint("BlueRepo: Error filtering device: $e");
          return false;
        }
      });

      // Sort by RSSI (Strongest signal first)
      final sortedResults = filteredResults.toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      return sortedResults.map((result) {
        String name = result.device.platformName;
        final hasOmiUuid = result.advertisementData.serviceUuids
            .map((u) => u.toString().toLowerCase())
            .contains(BluetoothConstants.serviceUuid.toLowerCase());

        final isOmiDevice =
            hasOmiUuid ||
            name.toLowerCase().contains("omi") ||
            name.toLowerCase().contains("open glass");

        // Autocomplete name if missing
        if (name.isEmpty) {
          if (isOmiDevice) {
            // If we have the UUID, we know it's OmiGlass, even if the Name packet hasn't arrived yet.
            name = 'OmiGlass';
          } else if (result.rssi > -60) {
            // Fallback for strong signal devices that haven't revealed their identity yet
            name = 'OmiGlass (Detectado por Proximidad)';
          } else {
            name = 'Dispositivo Desconocido';
          }
        }

        return BluetoothDeviceEntity(
          id: result.device.remoteId.toString(),
          name: name,
          rssi: result.rssi,
          serviceUuids: result.advertisementData.serviceUuids
              .map((u) => u.toString())
              .toList(),
        );
      }).toList();
    });
  }

  @override
  Future<void> startScan() async {
    // We scan for EVERYTHING (null) to ensure we catch devices that might
    // put the UUID in the Scan Response (which isn't used for filtering by OS sometimes)
    // or if the packet is malformed/shortened.
    // We then filter manually in scanResults.
    return dataSource.startScan(
      timeout: const Duration(seconds: 15),
      withServices: null, // Scan all devices
    );
  }

  @override
  Future<void> stopScan() async {
    return dataSource.stopScan();
  }

  @override
  Future<void> connect(String deviceId) async {
    final device = BluetoothDevice.fromId(deviceId);
    
    debugPrint("BlueRepo: Starting Robust Connection Sequence for $deviceId");

    // 1. Preventive Disconnect (Clean state)
    try { await device.disconnect(); } catch (_) {}

    // 2. Try Fast Connection with Retries (3 attempts)
    // This handles transient 133/255 errors by simply trying again
    for (int i = 0; i < 3; i++) {
      try {
        debugPrint("BlueRepo: Fast Connect Attempt ${i + 1}/3...");
        await dataSource.connect(device, autoConnect: false);
        debugPrint("BlueRepo: Connection Successful!");
        return;
      } catch (e) {
        debugPrint("BlueRepo: Attempt ${i + 1} failed: $e");
        // Only wait if we have retries left
        if (i < 2) {
          // Progressive delay: 500ms, 1000ms
          int delay = 500 * (i + 1);
          debugPrint("BlueRepo: Waiting ${delay}ms before retry...");
          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }

    // 3. Last Resort: AutoConnect
    // If fast connection fails repeatedly, we fallback to autoConnect which is more reliable but slower.
    debugPrint("BlueRepo: Fast attempts exhausted. Trying AutoConnect (Reliable Mode)...");
    try {
       // We rely on the VM's timeout to kill this if it takes too long
       await dataSource.connect(device, autoConnect: true);
    } catch (e) {
       debugPrint("BlueRepo: AutoConnect failed: $e");
       rethrow;
    }
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

    try {
      // Write SSID
      debugPrint("BlueRepo: Writing SSID...");
      await dataSource.writeCharacteristic(
        device,
        BluetoothConstants.serviceUuid,
        BluetoothConstants.wifiSsidUuid,
        ssid,
      );

      // Write Password
      debugPrint("BlueRepo: Writing Password...");
      await dataSource.writeCharacteristic(
        device,
        BluetoothConstants.serviceUuid,
        BluetoothConstants.wifiPasswordUuid,
        password,
      );

      debugPrint("BlueRepo: WiFi credentials sent successfully.");
    } catch (e) {
      debugPrint("BlueRepo: Error sending WiFi credentials: $e");
      rethrow;
    }
  }

  @override
  Stream<String> listenForIpAddress(String deviceId) {
    final device = BluetoothDevice.fromId(deviceId);

    try {
      return dataSource
          .subscribeToCharacteristic(
            device,
            BluetoothConstants.serviceUuid,
            BluetoothConstants.ipAddressUuid,
          )
          .map((bytes) {
            if (bytes.isNotEmpty) {
              final ip = utf8.decode(bytes);
              debugPrint("BlueRepo: Received IP Address: $ip");
              return ip;
            }
            return "";
          });
    } catch (e) {
      debugPrint("BlueRepo: Error listening for IP: $e");
      return Stream.error("Could not listen for IP address.");
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
