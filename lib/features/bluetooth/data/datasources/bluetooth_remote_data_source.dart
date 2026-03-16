import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

abstract class BluetoothRemoteDataSource {
  Stream<List<ScanResult>> get scanResults;
  Future<void> startScan({Duration? timeout, List<String>? withServices});
  Future<void> stopScan();
  Future<void> connect(BluetoothDevice device, {bool autoConnect = true});
  Future<void> disconnect(BluetoothDevice device);
  Future<List<String>> discoverServices(BluetoothDevice device);
  Future<void> writeCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
    String value,
  );
  Future<void> writeCharacteristicBytes(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
    List<int> value,
  );

  /// Writes bytes to ALL writable characteristics found on the device.
  /// This is a "Broadcast" method for debugging when the correct characteristic is unknown.
  Future<List<String>> writeToAllRelevantCharacteristics(
    BluetoothDevice device,
    List<int> value,
  );

  Future<List<int>> readCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
  );

  Stream<List<int>> subscribeToCharacteristic(
    BluetoothDevice device,
    
    String serviceUuid,
    String charUuid,
  );

  Future<bool> hasService(BluetoothDevice device, String serviceUuid);

  Stream<String> monitorAllServices(BluetoothDevice device);

  Future<List<BluetoothDevice>> get connectedDevices;

  // Bluetooth State
  Future<bool> get isBluetoothEnabled;
  Stream<bool> get bluetoothState;
  Future<void> turnOnBluetooth();
}

class BluetoothRemoteDataSourceImpl implements BluetoothRemoteDataSource {
  // Lock to prevent concurrent reconnection attempts
  bool _isReconnecting = false;

  @override
  Future<List<BluetoothDevice>> get connectedDevices async {
    return FlutterBluePlus.connectedDevices;
  }

  @override
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  @override
  Future<void> startScan({Duration? timeout, List<String>? withServices}) {
    return FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: withServices?.map((s) => Guid(s)).toList() ?? [],
    );
  }

  @override
  Future<void> stopScan() {
    return FlutterBluePlus.stopScan();
  }

  @override
  Future<bool> get isBluetoothEnabled async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Stream<bool> get bluetoothState {
    return FlutterBluePlus.adapterState.map(
      (s) => s == BluetoothAdapterState.on,
    );
  }

  @override
  Future<void> turnOnBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await FlutterBluePlus.turnOn();
      } catch (e) {
        debugPrint("Error turning on Bluetooth: $e");
        throw Exception("Could not turn on Bluetooth automatically.");
      }
    } else {
      throw Exception("Turn on Bluetooth in Settings.");
    }
  }

  @override
  Future<void> connect(
    BluetoothDevice device, {
    bool autoConnect = true,
  }) async {
    // DO NOT disconnect here automatically. It interferes with retry logic.
    // Only disconnect if we are forcing a full reset, which should be done outside or with a flag.

    // Force delay to ensure GATT is fully cleared if we were just disconnected
    // await Future.delayed(const Duration(milliseconds: 200));

    // Use autoConnect based on parameter
    debugPrint("Connecting with autoConnect: $autoConnect...");

    try {
      await device.connect(
        autoConnect: autoConnect,
        mtu: null, // REQUIRED for autoConnect: true
      );

      // Request MTU with a safe delay and error handling
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Run in background, don't await blocking the connection return
        Future.delayed(const Duration(seconds: 2), () async {
          if (device.isConnected) {
            debugPrint("Requesting high MTU (512) after delay...");
            try {
              // Also request high priority for faster throughput
              await device.requestConnectionPriority(
                connectionPriorityRequest: ConnectionPriority.high,
              );
              await Future.delayed(const Duration(milliseconds: 500));

              await device.requestMtu(512);
              int currentMtu = await device.mtu.first;
              debugPrint("Current MTU: $currentMtu");
            } catch (e) {
              debugPrint("Failed to request MTU: $e");
            }
          }
        });
      }
    } catch (e) {
      // If it fails, let the caller handle it or retry
      rethrow;
    }
  }

  @override
  Future<void> disconnect(BluetoothDevice device) {
    return device.disconnect();
  }

  @override
  Future<List<String>> discoverServices(BluetoothDevice device) async {
    // Wait a bit after connection before discovering services
    // This is often needed on Android to allow the GATT stack to settle
    await Future.delayed(const Duration(milliseconds: 2000));

    try {
      debugPrint("Discovering services for ${device.remoteId}...");
      List<BluetoothService> services = await device.discoverServices();

      if (services.isEmpty) {
        debugPrint("No services found. Retrying discovery in 2 seconds...");
        await Future.delayed(const Duration(seconds: 2));
        services = await device.discoverServices();
      }

      debugPrint("Found ${services.length} services.");
      List<String> debugInfo = [];
      for (var s in services) {
        String serviceInfo = "Service: ${s.uuid}";
        debugPrint(serviceInfo);
        debugInfo.add(serviceInfo);

        for (var c in s.characteristics) {
          String charInfo = "  -> Char: ${c.uuid} | Props: ${c.properties}";
          debugPrint(charInfo);
          debugInfo.add(charInfo);
        }
      }
      return debugInfo;
    } catch (e) {
      debugPrint("Error discovering services: $e");
      // Try one more time after a longer delay
      await Future.delayed(const Duration(seconds: 3));
      try {
        final services = await device.discoverServices();
        return services.map((s) => s.uuid.toString()).toList();
      } catch (e2) {
        debugPrint("Retry failed: $e2");
        return [];
      }
    }
  }

  Future<void> _ensureConnected(BluetoothDevice device) async {
    // Check global connected devices list first (most reliable source of truth)
    if (FlutterBluePlus.connectedDevices.any(
      (d) => d.remoteId == device.remoteId,
    )) {
      debugPrint(
        "Device ${device.remoteId} found in global connected list. Skipping reconnection.",
      );
      return;
    }

    // Check instance state
    if (device.isConnected) {
      debugPrint(
        "Device ${device.remoteId} instance reports connected. Skipping reconnection.",
      );
      return;
    }

    // NEW: Check if already connecting by checking connectionState stream briefly?
    // Or assume if we are here, we really need to connect.

    // Wait if another reconnection attempt is in progress
    if (_isReconnecting) {
      debugPrint("Reconnection already in progress. Waiting...");
      // Simply return to avoid stacking requests. The ongoing attempt will handle it.
      // If it fails, the user will have to retry manually, which is safer than infinite loops.
      return;
    }

    _isReconnecting = true;
    try {
      // Double check after lock
      if (device.isConnected) return;

      debugPrint(
        "Device ${device.remoteId} disconnected. Attempting to reconnect...",
      );

      // Use autoConnect: true generally for better reliability, unless explicitly needed otherwise.
      // We removed the aggressive "autoConnect: false" first attempt to avoid race conditions.
      try {
        await connect(device, autoConnect: true);
      } catch (e) {
        debugPrint("Connection failed: $e");
        rethrow;
      }

      // Wait for actual connection state
      debugPrint("Waiting for connection state to become 'connected'...");
      try {
        await device.connectionState
            .firstWhere((state) => state == BluetoothConnectionState.connected)
            .timeout(const Duration(seconds: 15));
        debugPrint("Reconnected successfully.");
      } catch (e) {
        debugPrint("Failed to reconnect within timeout: $e");
        throw Exception("Failed to reconnect to device");
      }
    } finally {
      _isReconnecting = false;
    }
  }

  @override
  Future<void> writeCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
    String value,
  ) async {
    await _ensureConnected(device);

    // Force service discovery if list is empty or invalid
    List<BluetoothService> services = device.servicesList;
    if (services.isEmpty) {
      debugPrint("Services list empty, discovering services...");
      await discoverServices(device);
      services = device.servicesList;
    } else {
      // Optional: Re-discover if we can't find the service we need in the cached list
      bool serviceExists = services.any(
        (s) => s.uuid.toString() == serviceUuid,
      );
      if (!serviceExists) {
        debugPrint(
          "Service $serviceUuid not found in cached list. Rediscovering...",
        );
        await discoverServices(device);
        services = device.servicesList;
      } else {
        debugPrint(
          "Using cached services list: ${services.length} services found.",
        );
      }
    }

    // DEBUG: Print all services and characteristics to help find the correct UUIDs
    for (var s in services) {
      if (s.uuid.toString() == serviceUuid) {
        debugPrint("Match Service: ${s.uuid}");
        for (var c in s.characteristics) {
          debugPrint("  -> Char: ${c.uuid} | Props: ${c.properties}");
        }
      }
    }

    final service = services.firstWhere(
      (s) => s.uuid.toString() == serviceUuid,
      orElse: () {
        debugPrint(
          "CRITICAL ERROR: Service $serviceUuid NOT found in list: ${services.map((s) => s.uuid.toString()).toList()}",
        );
        throw Exception('Service $serviceUuid not found');
      },
    );

    final characteristic = service.characteristics.firstWhere(
      (c) => c.uuid.toString() == charUuid,
      orElse: () {
        final availableChars = service.characteristics
            .map((c) => c.uuid.toString())
            .toList();
        debugPrint(
          "CRITICAL ERROR: Characteristic $charUuid NOT found in service $serviceUuid",
        );
        debugPrint("Available Characteristics: $availableChars");
        throw Exception(
          'Characteristic $charUuid not found. Available: $availableChars',
        );
      },
    );

    debugPrint("Writing to characteristic $charUuid: $value");
    await characteristic.write(utf8.encode(value));
    debugPrint("Write successful.");
  }

  @override
  Future<void> writeCharacteristicBytes(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
    List<int> value,
  ) async {
    await _ensureConnected(device);

    List<BluetoothService> services = device.servicesList;
    if (services.isEmpty) {
      await device.discoverServices();
      services = device.servicesList;
    }

    BluetoothCharacteristic? target;
    final targetGuid = Guid(charUuid);

    // 1. Exact UUID Match
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == targetGuid) {
          target = c;
          break;
        }
      }
      if (target != null) break;
    }

    // 2. Loose Match (String comparison)
    if (target == null) {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == charUuid.toLowerCase()) {
            target = c;
            break;
          }
        }
        if (target != null) break;
      }
    }

    if (target == null) {
      throw Exception('Characteristic $charUuid not found in device services');
    }
    if (!(target.properties.write || target.properties.writeWithoutResponse)) {
      throw Exception('Selected characteristic not writable');
    }
    debugPrint("Writing bytes to characteristic ${target.uuid}: $value");
    await target.write(value);
    debugPrint("Write successful.");
  }

  @override
  Future<List<String>> writeToAllRelevantCharacteristics(
    BluetoothDevice device,
    List<int> value,
  ) async {
    await _ensureConnected(device);

    // Ensure services are discovered
    if (device.servicesList.isEmpty) {
      await device.discoverServices();
    }

    final List<String> log = [];
    final services = device.servicesList;

    log.add("Starting broadcast write...");

    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          try {
            await c.write(
              value,
              withoutResponse: c.properties.writeWithoutResponse,
            );
            log.add("Success: ${c.uuid} (Service: ${s.uuid})");
            debugPrint("Broadcast Write to ${c.uuid} OK");
          } catch (e) {
            log.add("Failed: ${c.uuid} ($e)");
            debugPrint("Broadcast Write to ${c.uuid} Failed: $e");
          }
        }
      }
    }

    return log;
  }

  @override
  Future<List<int>> readCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
  ) async {
    await _ensureConnected(device);

    List<BluetoothService> services = device.servicesList;
    if (services.isEmpty) {
      await device.discoverServices();
      services = device.servicesList;
    }

    BluetoothCharacteristic? target;
    final targetGuid = Guid(charUuid);

    // 1. Exact UUID Match
    for (final s in services) {
      for (final c in s.characteristics) {
        if (c.uuid == targetGuid) {
          target = c;
          break;
        }
      }
      if (target != null) break;
    }

    // 2. Loose Match (String comparison)
    if (target == null) {
      for (final s in services) {
        for (final c in s.characteristics) {
          if (c.uuid.toString().toLowerCase() == charUuid.toLowerCase()) {
            target = c;
            break;
          }
        }
        if (target != null) break;
      }
    }

    if (target == null) {
      throw Exception('Characteristic $charUuid not found in device services');
    }
    if (!target.properties.read) {
      throw Exception('Selected characteristic not readable');
    }
    debugPrint("Reading bytes from characteristic ${target.uuid}...");
    final value = await target.read();
    debugPrint("Read successful: $value");
    return value;
  }

  @override
  Stream<List<int>> subscribeToCharacteristic(
    BluetoothDevice device,
    String serviceUuid,
    String charUuid,
  ) async* {
    await _ensureConnected(device);

    List<BluetoothService> services = device.servicesList;
    if (services.isEmpty) {
      await discoverServices(device);
      services = device.servicesList;
    }

    if (!services.any((s) => s.uuid.toString() == serviceUuid)) {
      await discoverServices(device);
      services = device.servicesList;
    }

    final service = services.firstWhere(
      (s) => s.uuid.toString() == serviceUuid,
      orElse: () => throw Exception('Service $serviceUuid not found'),
    );

    BluetoothCharacteristic characteristic;
    try {
      characteristic = service.characteristics.firstWhere(
        (c) => c.uuid.toString() == charUuid,
      );
    } catch (_) {
      try {
        characteristic = service.characteristics.firstWhere(
          (c) => c.properties.notify,
        );
        debugPrint(
          "FALLBACK: Using notifiable characteristic ${characteristic.uuid} in service $serviceUuid",
        );
      } catch (_) {
        characteristic = service.characteristics.first;
        debugPrint(
          "FALLBACK: Using first available characteristic ${characteristic.uuid} in service $serviceUuid",
        );
      }
    }

    debugPrint("Subscribing to characteristic $charUuid...");

    // Ensure we start listening BEFORE enabling notifications to miss nothing
    final stream = characteristic.onValueReceived;

    await characteristic.setNotifyValue(true);

    yield* stream;
  }

  @override
  Future<bool> hasService(BluetoothDevice device, String serviceUuid) async {
    try {
      List<BluetoothService> services = device.servicesList;
      if (services.isEmpty) {
        try {
          await device.discoverServices();
          services = device.servicesList;
        } catch (_) {
          // If discovery fails, we can't check
        }
      }
      return services.any((s) => s.uuid.toString() == serviceUuid);
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<String> monitorAllServices(BluetoothDevice device) {
    // This is a debug method to listen to EVERYTHING
    // We create a controller that will receive events from all characteristics
    final controller = StreamController<String>.broadcast();
    final List<StreamSubscription> subscriptions = [];

    controller.onCancel = () {
      debugPrint("Stopping debug monitor for ${device.remoteId}");
      for (final sub in subscriptions) {
        sub.cancel();
      }
      subscriptions.clear();
    };

    // Run async logic to set up listeners without blocking the return of the stream
    Future.microtask(() async {
      try {
        // Wait a bit to ensure services are ready
        if (device.servicesList.isEmpty) {
          await device.discoverServices();
        }

        final services = device.servicesList;
        controller.add("Discovered ${services.length} services:");

        for (final s in services) {
          controller.add("Service: ${s.uuid}");
          for (final c in s.characteristics) {
            final props = [];
            if (c.properties.read) props.add("Read");
            if (c.properties.write) props.add("Write");
            if (c.properties.writeWithoutResponse) props.add("WriteNoResp");
            if (c.properties.notify) props.add("Notify");
            if (c.properties.indicate) props.add("Indicate");

            controller.add("  - Char: ${c.uuid} [${props.join(', ')}]");

            if (c.properties.notify || c.properties.indicate) {
              try {
                // Enable notifications
                await c.setNotifyValue(true);
                // Listen to value changes
                final sub = c.onValueReceived.listen((value) {
                  if (value.isNotEmpty) {
                    final hex = value
                        .map((b) => b.toRadixString(16).padLeft(2, '0'))
                        .join(' ');
                    final log = "[${c.uuid}] Data: $hex";
                    debugPrint(log);
                    controller.add(log);
                  }
                });
                subscriptions.add(sub);
                controller.add("    -> Subscribed OK");
              } catch (e) {
                debugPrint("Failed to subscribe to ${c.uuid}: $e");
                controller.add("    -> Error subscribing: $e");
              }
            }
          }
        }
      } catch (e) {
        controller.add("Error discovering services for monitoring: $e");
      }
    });

    return controller.stream;
  }
}
