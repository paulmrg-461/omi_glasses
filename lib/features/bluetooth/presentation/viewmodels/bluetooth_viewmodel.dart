import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
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
  StreamSubscription? _imageSubscription;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _batterySubscription;

  // Audio State
  FlutterSoundPlayer? _audioPlayer;
  bool _isAudioEnabled = false;
  bool get isAudioEnabled => _isAudioEnabled;

  // Battery State
  int? _batteryLevel;
  int? get batteryLevel => _batteryLevel;

  // Image State
  Uint8List? _lastImage;
  Uint8List? get lastImage => _lastImage;

  String? _imageHeaderHex;
  String? get imageHeaderHex => _imageHeaderHex;

  String? _imageTransferStatus;
  String? get imageTransferStatus => _imageTransferStatus;

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

        // Start monitoring battery automatically
        startBatteryListener();
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

    // Prevent multiple subscriptions
    if (_imageSubscription != null) return;

    _imageTransferStatus = "Listening for images...";
    notifyListeners();

    try {
      _imageSubscription = repository
          .listenToImages(_connectedDevice!.id)
          .listen(
            (event) {
              if (event is ImageReceptionProgress) {
                _imageTransferStatus =
                    "Receiving: ${event.bytesReceived} bytes (${event.packetsReceived} pkts)";
                notifyListeners();
              } else if (event is ImageReceptionSuccess) {
                _lastImage = event.imageBytes;
                _imageHeaderHex = event.imageBytes
                    .take(20)
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(' ');
                _imageTransferStatus =
                    "Image Received! (${event.imageBytes.length} bytes)";
                notifyListeners();
              } else if (event is ImageReceptionError) {
                _errorMessage = "Image Error: ${event.error}";
                notifyListeners();
              }
            },
            onError: (e) {
              _errorMessage = "Image Stream Error: $e";
              notifyListeners();
            },
          );
    } catch (e) {
      _errorMessage = "Failed to start image listener: $e";
      notifyListeners();
    }
  }

  Future<void> triggerPhoto() async {
    if (_connectedDevice == null) return;

    // Ensure we are listening
    startImageListener();

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

    // Ensure we are listening
    startImageListener();

    try {
      await repository.startVideo(_connectedDevice!.id);
      _statusMessage = "Video started";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to start video: $e";
      notifyListeners();
    }
  }

  // Audio Methods

  Future<void> _initAudio() async {
    if (_audioPlayer != null) return;
    _audioPlayer = FlutterSoundPlayer();
    try {
      // Open player
      await _audioPlayer!.openPlayer();
      debugPrint("Audio player opened");

      // Configure Audio Session for Speaker Output (Playback Only)
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.allowBluetooth,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.audibilityEnforced,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      debugPrint("Audio session configured for speaker");
    } catch (e) {
      debugPrint("Failed to open audio player or configure session: $e");
      _errorMessage = "Audio Init Failed: $e";
      notifyListeners();
    }
  }

  Future<void> toggleAudio() async {
    debugPrint("Toggle audio called. Current state: $_isAudioEnabled");
    if (_isAudioEnabled) {
      await stopAudio();
    } else {
      await startAudio();
    }
  }

  Future<void> startAudio() async {
    if (_connectedDevice == null) return;

    // Request microphone permission (required for playAndRecord session)
    // final status = await Permission.microphone.request();
    // if (status != PermissionStatus.granted) {
    //   _errorMessage = "Microphone permission required for audio";
    //   notifyListeners();
    //   return;
    // }

    await _initAudio();

    if (_audioPlayer == null || !_audioPlayer!.isOpen()) {
      _errorMessage = "Audio player not initialized";
      notifyListeners();
      return;
    }

    try {
      debugPrint("Starting audio player stream...");
      // Start playing stream (PCM 16-bit, 16kHz, Mono)
      await _audioPlayer!.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
        interleaved: false,
      );

      _statusMessage = "Starting audio stream...";
      notifyListeners();

      debugPrint("Subscribing to repository audio stream...");
      _audioSubscription = repository
          .startAudioStream(_connectedDevice!.id)
          .listen(
            (data) {
              if (_audioPlayer != null && _audioPlayer!.isPlaying) {
                // feed the player
                // debugPrint("Feeding ${data.length} bytes to audio player");
                _audioPlayer!.uint8ListSink!.add(data);
              }
            },
            onError: (e) {
              debugPrint("Audio Stream Error in ViewModel: $e");
              _errorMessage = "Audio Stream Error: $e";
              notifyListeners();
              stopAudio();
            },
            onDone: () {
              debugPrint("Audio Stream Done in ViewModel");
              stopAudio();
            },
          );

      _isAudioEnabled = true;
      _statusMessage = "Audio started";
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to start audio in ViewModel: $e");
      _errorMessage = "Failed to start audio: $e";
      notifyListeners();
      await stopAudio();
    }
  }

  Future<void> stopAudio() async {
    debugPrint("Stopping audio...");
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      if (_audioPlayer != null && _audioPlayer!.isPlaying) {
        await _audioPlayer!.stopPlayer();
      }

      if (_connectedDevice != null) {
        await repository.stopAudioStream(_connectedDevice!.id);
      }

      _isAudioEnabled = false;
      _statusMessage = "Audio stopped";
      notifyListeners();
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }
  }

  Future<void> startBatteryListener() async {
    if (_connectedDevice == null) return;

    // Cancel previous if any
    await _batterySubscription?.cancel();

    debugPrint("Starting battery listener...");
    try {
      _batterySubscription = repository
          .monitorBatteryLevel(_connectedDevice!.id)
          .listen(
            (level) {
              debugPrint("Battery Level Received: $level%");
              _batteryLevel = level;
              notifyListeners();
            },
            onError: (e) {
              debugPrint("Error reading battery: $e");
            },
          );
    } catch (e) {
      debugPrint("Failed to start battery listener: $e");
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
    _imageSubscription?.cancel();
    _audioSubscription?.cancel();
    _batterySubscription?.cancel();
    _audioPlayer?.closePlayer();
    super.dispose();
  }
}
