import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:omi_glasses/core/constants/bluetooth_constants.dart';
import 'package:omi_glasses/core/services/foreground_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../domain/entities/bluetooth_device_entity.dart';
import '../../domain/repositories/bluetooth_repository.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../../vision/domain/repositories/vision_repository.dart';
import '../../../audio/domain/repositories/audio_repository.dart';
import '../../../memory/domain/repositories/memory_repository.dart';
import '../../../memory/domain/entities/memory_entry.dart';
import '../../../photo/domain/repositories/photo_repository.dart';
import '../../../photo/domain/entities/photo_entry.dart';
import '../../../audio/domain/repositories/audio_repository.dart'
    as audiodomain;

class BluetoothViewModel extends ChangeNotifier {
  final BluetoothRepository repository;
  final SettingsRepository settingsRepository;
  final VisionRepository visionRepository;
  final AudioRepository audioRepository;
  final MemoryRepository memoryRepository;
  final PhotoRepository photoRepository;
  final audiodomain.AudioRepositoryStructured _audioStructured =
      GetIt.instance<audiodomain.AudioRepositoryStructured>();

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

  BluetoothDeviceEntity? _selectedDevice;
  BluetoothDeviceEntity? get connectedDevice => _selectedDevice;

  List<BluetoothDeviceEntity> _connectedDevices = [];
  List<BluetoothDeviceEntity> get connectedDevices => _connectedDevices;

  List<String> _connectedDeviceServices = [];
  List<String> get connectedDeviceServices => _connectedDeviceServices;

  String? _cameraIp;
  String? get cameraIp => _cameraIp;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _ipSubscription;
  StreamSubscription? _imageSubscription;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _heartRateSubscription;
  StreamSubscription? _debugSubscription;

  // Audio State
  FlutterSoundPlayer? _audioPlayer;
  bool _isAudioEnabled = false;
  bool get isAudioEnabled => _isAudioEnabled;
  final FlutterTts _tts = FlutterTts();
  final List<int> _conversationPcm = [];
  DateTime _lastVoiceTs = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _silenceTimer;
  // Use seconds for faster feedback during testing
  final int _silenceSeconds = 15;

  // Real-time WebSocket for continuous audio
  IOWebSocketChannel? _audioWsChannel;
  bool _isWsReady = false;
  String? _currentWsSessionId;

  // Role assignments
  String? _audioDeviceId;
  String? get audioDeviceId => _audioDeviceId;
  String? _photoDeviceId;
  String? get photoDeviceId => _photoDeviceId;
  Timer? _photoTimer;
  Timer? _healthDataTimer;
  Timer? _watchdogTimer;

  // Battery State
  int? _batteryLevel;
  int? get batteryLevel => _batteryLevel;

  // Heart Rate State
  int? _heartRate;
  int? get heartRate => _heartRate;

  // Health Data State (Y25 Band)
  int _steps = 0;
  int get steps => _steps;
  int _calories = 0;
  int get calories => _calories;
  double _distanceKm = 0.0;
  double get distanceKm => _distanceKm;
  int _bloodOxygen = 0;
  int get bloodOxygen => _bloodOxygen;
  double _temperature = 0.0;
  double get temperature => _temperature;
  int _stress = 0;
  int get stress => _stress;
  String _sleepDuration = "0h 0m";
  String get sleepDuration => _sleepDuration;

  // Debug for proprietary services
  List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;

  // Image State
  Uint8List? _lastImage;
  Uint8List? get lastImage => _lastImage;

  String? _imageHeaderHex;
  String? get imageHeaderHex => _imageHeaderHex;

  String? _imageTransferStatus;
  String? get imageTransferStatus => _imageTransferStatus;
  bool _photoJustSaved = false;
  bool get photoJustSaved => _photoJustSaved;

  BluetoothViewModel({
    required this.repository,
    required this.settingsRepository,
    required this.visionRepository,
    required this.audioRepository,
    required this.memoryRepository,
    required this.photoRepository,
  }) {
    _startWatchdog();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      // 1. Ensure Audio is streaming if a device is assigned
      if (_audioDeviceId != null && _audioDeviceId!.isNotEmpty) {
        if (!_isAudioEnabled || _audioSubscription == null) {
          debugPrint(
            "Watchdog: Audio should be enabled but isn't. Restarting...",
          );
          // We use startAudio() directly which uses _audioDeviceId
          await startAudio();
        }
      }

      // 2. Ensure WebSocket is connected if audio is enabled
      if (_isAudioEnabled && (_audioWsChannel == null || !_isWsReady)) {
        debugPrint(
          "Watchdog: WebSocket should be connected but isn't. Re-init...",
        );
        await _initAudioWs();
      }

      // 3. Health data polling "Keep Alive" for Y25
      final healthDevice = _connectedDevices.firstWhere(
        (d) =>
            d.name.toUpperCase().contains("Y25") ||
            d.name.toUpperCase().contains("LEFUN"),
        orElse: () =>
            BluetoothDeviceEntity(id: '', name: '', rssi: 0, serviceUuids: []),
      );
      if (healthDevice.id.isNotEmpty && _healthDataTimer == null) {
        debugPrint(
          "Watchdog: Health device connected but monitoring stopped. Restarting...",
        );
        startHealthMonitoring();
      }
    });
  }

  Future<void> autoReconnectFromSettings() async {
    try {
      final settings = await settingsRepository.load();
      final ids = <String>{};
      if (settings.audioDeviceId != null &&
          settings.audioDeviceId!.isNotEmpty) {
        ids.add(settings.audioDeviceId!);
      }
      if (settings.photoDeviceId != null &&
          settings.photoDeviceId!.isNotEmpty) {
        ids.add(settings.photoDeviceId!);
      }
      if (settings.healthDeviceId != null &&
          settings.healthDeviceId!.isNotEmpty) {
        ids.add(settings.healthDeviceId!);
      }
      if (ids.isEmpty) {
        return;
      }

      try {
        final isBlueOn = await repository.isBluetoothEnabled;
        if (!isBlueOn) {
          return;
        }
      } catch (_) {}

      try {
        await repository.startScan();
      } catch (_) {}

      List<BluetoothDeviceEntity> snapshot = [];
      try {
        snapshot = await repository.scanResults.first.timeout(
          const Duration(seconds: 5),
        );
      } catch (_) {}

      try {
        await repository.stopScan();
      } catch (_) {}

      for (final id in ids) {
        final exists = snapshot.any((d) => d.id == id);
        if (exists) {
          await connect(id);
        }
      }
    } catch (_) {}
  }

  Future<void> startScan() async {
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    // Check Bluetooth state first
    try {
      final isBlueOn = await repository.isBluetoothEnabled;
      if (!isBlueOn) {
        _errorMessage = "Bluetooth está desactivado. Por favor enciéndelo.";
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint("Error checking bluetooth state: $e");
    }

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

    try {
      await repository.startScan();
    } catch (e) {
      _errorMessage = "Error starting scan: $e";
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> enableBluetooth() async {
    try {
      await repository.turnOnBluetooth();
      // Wait for it to initialize
      await Future.delayed(const Duration(seconds: 2));
      // Retry scan
      startScan();
    } catch (e) {
      _errorMessage = "No se pudo encender Bluetooth. Ve a Configuración.";
      notifyListeners();
    }
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
      final newDevice = _devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => BluetoothDeviceEntity(
          id: deviceId,
          name: 'Unknown',
          rssi: 0,
          serviceUuids: [],
        ),
      );

      // Add to connected list if not already present
      if (!_connectedDevices.any((d) => d.id == deviceId)) {
        _connectedDevices.add(newDevice);
      }

      // Set as selected (active) device
      _selectedDevice = newDevice;

      // Discover services to verify connection and capability
      try {
        // This now returns detailed service/characteristic info for debugging
        _connectedDeviceServices = await repository.discoverServices(deviceId);

        // Assign roles based on device name as specified by user
        final name = newDevice.name.toUpperCase();

        if (name == "OMI") {
          debugPrint("OMI device connected. Assigning Audio role.");
          // If we have an existing audio source (maybe OMI Glasses), replace it
          if (_audioDeviceId != deviceId) {
            await stopAudio();
          }
          await setAudioSource(deviceId);
        } else if (name == "OMI GLASSES") {
          debugPrint("OMI Glasses connected. Assigning Photo role.");
          await setPhotoSource(deviceId);

          // If no OMI device is providing audio, OMI Glasses acts as backup
          final hasOmiAudio = _connectedDevices.any(
            (d) => d.name.toUpperCase() == "OMI",
          );
          if (!hasOmiAudio && _audioDeviceId == null) {
            debugPrint(
              "No OMI audio device found. OMI Glasses acting as backup.",
            );
            await setAudioSource(deviceId);
          }
        } else if (name.contains("Y25") ||
            name.contains("LEFUN") ||
            name.contains("WATCH")) {
          debugPrint("Y25 Health device connected. Assigning Health role.");
          startHealthMonitoring();
          triggerY25Init();
        }

        // Start monitoring battery automatically
        try {
          startBatteryListener();
        } catch (e) {
          debugPrint("Battery service not found or error: $e");
        }

        // Start debug listener for raw data
        startDebugListener(deviceId);
      } catch (e) {
        debugPrint("Error discovering services: $e");
        _connectedDeviceServices = ["Error discovering services: $e"];
      }

      try {
        await ForegroundService.ensureStarted(this);
      } catch (e) {
        debugPrint("Failed to start foreground service: $e");
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

  Future<void> disconnect([String? deviceId]) async {
    // If no deviceId provided, try to disconnect the selected one
    final targetId = deviceId ?? _selectedDevice?.id;

    if (targetId != null) {
      final settings = await settingsRepository.load();
      // Remove from list
      _connectedDevices.removeWhere((d) => d.id == targetId);

      // If it was the selected device, clear selection
      if (_selectedDevice?.id == targetId) {
        _selectedDevice = null;
        _connectedDeviceServices = [];
        _debugSubscription?.cancel();
        _debugLogs.clear();
      }

      // Cleanup roles if the device was assigned
      if (_audioDeviceId == targetId) {
        await stopAudio();
        _audioDeviceId = null;

        // If "OMI" disconnected, check if we can fallback to "OMI GLASSES"
        final omiGlasses = _connectedDevices.firstWhere(
          (d) => d.name.toUpperCase() == "OMI GLASSES",
          orElse: () => BluetoothDeviceEntity(
            id: '',
            name: '',
            rssi: 0,
            serviceUuids: [],
          ),
        );
        if (omiGlasses.id.isNotEmpty) {
          debugPrint(
            "Fallback: OMI disconnected, assigning audio to OMI GLASSES.",
          );
          await setAudioSource(omiGlasses.id);
        }
      }
      if (_photoDeviceId == targetId) {
        _photoTimer?.cancel();
        _photoTimer = null;
        _photoDeviceId = null;
      }
      if (settings.healthDeviceId == targetId) {
        _healthDataTimer?.cancel();
        _healthDataTimer = null;
      }

      notifyListeners();
      await repository.disconnect(targetId);
    }
  }

  void clearSelectedDevice() {
    _selectedDevice = null;
    _connectedDeviceServices = [];
    notifyListeners();
  }

  void selectDevice(BluetoothDeviceEntity device) {
    _selectedDevice = device;
    // Trigger service discovery to refresh the view for the selected device
    retryServiceDiscovery();
    notifyListeners();
  }

  Future<void> retryServiceDiscovery() async {
    if (_selectedDevice != null) {
      _connectedDeviceServices = await repository.discoverServices(
        _selectedDevice!.id,
      );
      notifyListeners();
    }
  }

  void startImageListener() {
    if (_selectedDevice == null) return;

    // Prevent multiple subscriptions
    if (_imageSubscription != null) return;

    _imageTransferStatus = "Listening for images...";
    notifyListeners();

    try {
      _imageSubscription = repository
          .listenToImages(_selectedDevice!.id)
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
                _describeAndSpeak(event.imageBytes);
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

  void startImageListenerFor(String deviceId) {
    // Cancel previous to avoid multiple active listeners
    _imageSubscription?.cancel();
    _imageSubscription = null;
    _imageTransferStatus = "Listening for images...";
    notifyListeners();

    try {
      _imageSubscription = repository
          .listenToImages(deviceId)
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
                _describeAndSpeak(event.imageBytes);
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
    String? targetId = _photoDeviceId;

    if (targetId == null && _selectedDevice != null) {
      final isCapable = await repository.hasService(
        _selectedDevice!.id,
        BluetoothConstants.serviceUuid,
      );
      if (isCapable) targetId = _selectedDevice!.id;
    }

    if (targetId == null) {
      debugPrint("Cannot trigger photo: No photo-capable device.");
      return;
    }

    // Ensure we are listening
    startImageListenerFor(targetId);

    try {
      await repository.triggerPhoto(targetId);
      _statusMessage = "Photo triggered";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to trigger photo: $e";
      notifyListeners();
    }
  }

  Future<void> triggerPhotoFor(String deviceId) async {
    startImageListenerFor(deviceId);
    try {
      await repository.triggerPhoto(deviceId);
      _statusMessage = "Photo triggered";
      notifyListeners();
    } catch (e) {
      _errorMessage = "Failed to trigger photo: $e";
      notifyListeners();
    }
  }

  Future<void> startVideo() async {
    String? targetId = _photoDeviceId;

    if (targetId == null && _selectedDevice != null) {
      final isCapable = await repository.hasService(
        _selectedDevice!.id,
        BluetoothConstants.serviceUuid,
      );
      if (isCapable) targetId = _selectedDevice!.id;
    }

    if (targetId == null) {
      debugPrint("Cannot start video: No video-capable device.");
      return;
    }

    // Ensure we are listening
    startImageListenerFor(targetId);

    try {
      await repository.startVideo(targetId);
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

  Future<void> _initAudioWs() async {
    if (_audioWsChannel != null) return;

    try {
      final settings = await settingsRepository.load();
      // Use setting URL or default if not set
      String url = settings.localAudioUrl ?? "";

      // Ensure ws protocol and proper endpoint
      if (url.isEmpty) {
        url = "ws://192.168.1.15:8989/ws/audio";
      } else {
        if (url.startsWith('http://')) {
          url = url.replaceFirst('http://', 'ws://');
        } else if (url.startsWith('https://')) {
          url = url.replaceFirst('https://', 'wss://');
        }

        if (!url.startsWith('ws')) {
          url = 'ws://$url';
        }

        if (!url.contains('/ws/audio')) {
          final separator = url.endsWith('/') ? '' : '/';
          url = '$url${separator}ws/audio';
        }
      }

      debugPrint("Connecting to Audio WebSocket: $url");
      _audioWsChannel = IOWebSocketChannel.connect(Uri.parse(url));

      _currentWsSessionId = "session_${DateTime.now().millisecondsSinceEpoch}";

      _audioWsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'ready') {
              debugPrint("WebSocket Server Ready. Sending config...");
              _sendWsConfig();
            } else if (data['type'] == 'final_result') {
              debugPrint(
                "Transcription Received: ${data['analysis']['transcription']}",
              );
              // Handle real-time result
              final summary = data['analysis']['summary'] ?? '';
              if (summary.isNotEmpty) {
                _statusMessage = "Resumen (WS): $summary";
                notifyListeners();
              }
            }
          } catch (e) {
            debugPrint("Error parsing WS message: $e");
          }
        },
        onError: (e) {
          debugPrint("WebSocket Stream Error: $e");
          _isWsReady = false;
          _audioWsChannel = null;
          // Reconnect if still enabled
          if (_isAudioEnabled) {
            Future.delayed(const Duration(seconds: 5), _initAudioWs);
          }
        },
        onDone: () {
          debugPrint("WebSocket Connection Closed");
          _isWsReady = false;
          _audioWsChannel = null;
          // Reconnect if still enabled
          if (_isAudioEnabled) {
            Future.delayed(const Duration(seconds: 2), _initAudioWs);
          }
        },
      );
    } catch (e) {
      debugPrint("Failed to connect to Audio WebSocket: $e");
      _isWsReady = false;
      _audioWsChannel = null;
    }
  }

  void _sendWsConfig() {
    if (_audioWsChannel == null || _currentWsSessionId == null) return;

    final config = {
      'type': 'config',
      'session_id': _currentWsSessionId,
      'sample_rate': 16000,
      'encoding': 'pcm16',
      'language': 'es',
    };
    _audioWsChannel!.sink.add(jsonEncode(config));
    _isWsReady = true;
    debugPrint("WebSocket Config Sent");
  }

  void _sendAudioToWs(Uint8List data) {
    if (_audioWsChannel != null && _isWsReady) {
      _audioWsChannel!.sink.add(data);
    }
  }

  void _finishWsSegment() {
    if (_audioWsChannel != null && _isWsReady) {
      debugPrint("Finishing WS Segment to get results...");
      _audioWsChannel!.sink.add(jsonEncode({'type': 'end_of_stream'}));
      // The server will send final_result and likely close the connection.
      // Our onDone handler will automatically reconnect and start a new session.
    }
  }

  Future<void> startAudio() async {
    // Determine target device: _audioDeviceId takes precedence, then _selectedDevice
    String? targetId = _audioDeviceId;
    if (targetId == null && _selectedDevice != null) {
      // Check if selected device is audio capable
      final isAudioCapable = await repository.hasService(
        _selectedDevice!.id,
        BluetoothConstants.serviceUuid,
      );
      if (isAudioCapable) {
        targetId = _selectedDevice!.id;
      }
    }

    if (targetId == null) {
      debugPrint("Cannot start audio: No audio-capable device selected.");
      return;
    }

    await _initAudio();
    await _initAudioWs();

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

      debugPrint("Subscribing to repository audio stream from $targetId...");
      _audioSubscription = repository
          .startAudioStream(targetId)
          .listen(
            (data) {
              if (_audioPlayer != null && _audioPlayer!.isPlaying) {
                // feed the player
                _audioPlayer!.uint8ListSink!.add(data);
              }
              // Send to Real-time WebSocket
              _sendAudioToWs(data);
              _processAudioForSummary(data);
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
      _startSilenceMonitor();
    } catch (e) {
      debugPrint("Failed to start audio in ViewModel: $e");
      _errorMessage = "Failed to start audio: $e";
      notifyListeners();
      await stopAudio();
    }
  }

  Future<void> startAudioFrom(String deviceId) async {
    // If another audio is active, stop it first
    await stopAudio();
    _audioDeviceId = deviceId;
    // Temporarily set selected device to ensure audio session uses proper route
    _selectedDevice = _connectedDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => BluetoothDeviceEntity(
        id: deviceId,
        name: 'Unknown',
        rssi: 0,
        serviceUuids: [],
      ),
    );
    await startAudio();
  }

  Future<void> stopAudio() async {
    debugPrint("Stopping audio...");
    try {
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      if (_audioPlayer != null && _audioPlayer!.isPlaying) {
        await _audioPlayer!.stopPlayer();
      }

      if (_audioWsChannel != null) {
        debugPrint("Closing WebSocket...");
        _audioWsChannel!.sink.add(jsonEncode({'type': 'end_of_stream'}));
        _audioWsChannel!.sink.close(status.goingAway);
        _audioWsChannel = null;
        _isWsReady = false;
      }

      if (_selectedDevice != null) {
        await repository.stopAudioStream(_selectedDevice!.id);
      }

      _isAudioEnabled = false;
      _statusMessage = "Audio stopped";
      notifyListeners();
      _silenceTimer?.cancel();
    } catch (e) {
      debugPrint("Error stopping audio: $e");
    }
  }

  Future<void> startBatteryListener() async {
    if (_selectedDevice == null) return;

    // Cancel previous if any
    await _batterySubscription?.cancel();

    debugPrint("Starting battery listener...");
    try {
      _batterySubscription = repository
          .monitorBatteryLevel(_selectedDevice!.id)
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

  Future<void> startHeartRateListener() async {
    if (_selectedDevice == null) return;

    // Cancel previous if any
    await _heartRateSubscription?.cancel();

    debugPrint("Starting heart rate listener...");
    try {
      _heartRateSubscription = repository
          .monitorHeartRate(_selectedDevice!.id)
          .listen(
            (hr) {
              debugPrint("Heart Rate Received: $hr BPM");
              _heartRate = hr;
              notifyListeners();
            },
            onError: (e) {
              debugPrint("Error reading heart rate: $e");
            },
          );
    } catch (e) {
      debugPrint("Failed to start heart rate listener: $e");
    }
  }

  void startHealthMonitoring() {
    _healthDataTimer?.cancel();
    if (_selectedDevice == null) return;

    debugPrint("Starting Health Monitoring (Generic/Y25)...");

    // Poll every 5 seconds to keep data flowing (Fix for "Only 1 value")
    _healthDataTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (_selectedDevice == null) {
        timer.cancel();
        return;
      }

      // Alternate between different "Keep Alive" / "Request Data" commands
      // to cover different device variants (Y25 vs FitPro)

      // 1. FitPro Data Request
      await sendRawDebugCommand("CD 00 11");

      // 2. Y25 HR Request (only if we haven't seen updates recently?)
      // For now, let's just send it to be safe.
      await Future.delayed(const Duration(milliseconds: 500));
      await sendRawDebugCommand("AB 00 05 00 00 00 80");

      // 3. SpO2 Request (CD 00 23 01) - Force SpO2 measurement
      await Future.delayed(const Duration(milliseconds: 500));
      await sendRawDebugCommand("CD 00 23 01");
    });
  }

  void simulateHealthData() {
    // Demo data to visualize UI as requested
    final now = DateTime.now();
    _steps = 1250 + (now.second * 15);
    _calories = (_steps * 0.04).toInt();
    _distanceKm = double.parse((_steps * 0.0007).toStringAsFixed(2));
    _bloodOxygen = 98; // Healthy
    _temperature = 36.6;
    _stress = 42; // Low stress
    _sleepDuration = "7h 30m";

    // Randomize slightly
    if (now.second % 2 == 0) _bloodOxygen = 97;
    if (now.second % 5 == 0) _stress = 55;

    notifyListeners();
  }

  Future<void> setupWifi(String ssid, String password) async {
    if (_selectedDevice == null) return;

    _isSettingUpWifi = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    try {
      debugPrint("Starting Wi-Fi Setup for device: ${_selectedDevice!.id}");
      debugPrint("SSID: $ssid");

      // Cancel previous subscription if any
      _ipSubscription?.cancel();

      // Start listening for IP
      debugPrint("Subscribing to IP characteristic...");
      _ipSubscription = repository
          .listenForIpAddress(_selectedDevice!.id)
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
      await repository.sendWifiCredentials(_selectedDevice!.id, ssid, password);
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

  Future<void> setPhotoSource(
    String deviceId, {
    Duration interval = const Duration(seconds: 60),
  }) async {
    _photoDeviceId = deviceId;
    _photoTimer?.cancel();

    if (deviceId.isEmpty) {
      _statusMessage = "Captura de fotos desactivada";
      notifyListeners();
      return;
    }

    try {
      final s = await settingsRepository.load();
      interval = Duration(seconds: s.photoIntervalSeconds);
      // Save to settings
      await settingsRepository.save(s.copyWith(photoDeviceId: deviceId));
    } catch (_) {}
    // Start listening to images from the photo device
    startImageListenerFor(deviceId);
    // Restart timer
    _photoTimer = Timer.periodic(interval, (_) {
      if (_photoDeviceId != null && _photoDeviceId!.isNotEmpty) {
        triggerPhotoFor(_photoDeviceId!);
      }
    });
    _statusMessage = "Timer de fotos iniciado (cada ${interval.inSeconds}s)";
    notifyListeners();
  }

  Future<void> setAudioSource(String deviceId) async {
    await startAudioFrom(deviceId);
    try {
      final s = await settingsRepository.load();
      await settingsRepository.save(s.copyWith(audioDeviceId: deviceId));
    } catch (_) {}
    _statusMessage = "Audio source set";
    notifyListeners();
  }

  Future<void> setHealthSource(String deviceId) async {
    _selectedDevice = _connectedDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => _selectedDevice!,
    );
    startHealthMonitoring();
    triggerY25Init();
    try {
      final s = await settingsRepository.load();
      await settingsRepository.save(s.copyWith(healthDeviceId: deviceId));
    } catch (_) {}
    _statusMessage = "Health source set (Y25)";
    notifyListeners();
  }

  Future<void> sendRawDebugCommand(String hexCommand) async {
    if (_selectedDevice == null) return;
    try {
      final bytes = hexCommand
          .split(' ')
          .where((s) => s.isNotEmpty)
          .map((s) => int.parse(s, radix: 16))
          .toList();
      _debugLogs.add("Sending: $hexCommand");
      notifyListeners();

      // Try NUS Write (6e400002) first, then AE01
      bool sentToNus = false;
      try {
        await repository.writeCharacteristicBytes(
          _selectedDevice!.id,
          "6e400001-b5a3-f393-e0a9-e50e24dcca9e",
          "6e400002-b5a3-f393-e0a9-e50e24dcca9e",
          bytes,
        );
        _debugLogs.add("Sent to NUS (6e400002)");
        sentToNus = true;
      } catch (e1) {
        _debugLogs.add("NUS failed: $e1");
      }

      // Always try AE01 as well for Y25 bands, as they often have both but listen on AE01
      // If NUS succeeded, we can skip logging AE01 failures to reduce noise
      bool sentToAe01 = false;
      try {
        await repository.writeCharacteristicBytes(
          _selectedDevice!.id,
          "0000ae00-0000-1000-8000-00805f9b34fb",
          "0000ae01-0000-1000-8000-00805f9b34fb",
          bytes,
        );
        _debugLogs.add("Sent to AE01 (Success)");
        sentToAe01 = true;
      } catch (e2) {
        // Log AE01 error if it's NOT a "not supported" error (to avoid noise)
        // OR if NUS also failed (so we know both failed)
        final isNotSupported = e2.toString().contains(
          "WRITE property is not supported",
        );
        if (!sentToNus || !isNotSupported) {
          _debugLogs.add("AE01 failed: $e2");
        }
      }

      // If both specific writes failed (or even if they "succeeded" but we are debugging),
      // we can try the "Broadcast" method if the user really wants to force it.
      // But let's do it if specific writes failed OR if we are in a desperate "init" sequence.
      if (!sentToNus && !sentToAe01) {
        _debugLogs.add(
          "Specific writes failed. Broadcasting to ALL writable characteristics...",
        );
        try {
          final logs = await repository.writeToAllWritable(
            _selectedDevice!.id,
            bytes,
          );
          _debugLogs.addAll(logs);
        } catch (e) {
          _debugLogs.add("Broadcast write failed: $e");
        }
      } else {
        // Even if one succeeded, let's try AE30 specifically if it wasn't the one we just hit.
        // Actually, let's just use the broadcast method as a fallback always for now in debug mode
        // to ensure we hit the right one.
        // Or better: Add a specific check for AE30 service.
        try {
          await repository.writeCharacteristicBytes(
            _selectedDevice!.id,
            "0000ae30-0000-1000-8000-00805f9b34fb",
            "0000ae01-0000-1000-8000-00805f9b34fb",
            bytes,
          );
          _debugLogs.add("Sent to AE30/AE01 (Success)");
        } catch (e) {
          // Ignore AE30 failure if others worked
        }
      }

      notifyListeners();
    } catch (e) {
      _debugLogs.add("Invalid Hex: $e");
      notifyListeners();
    }
  }

  Future<void> triggerY25Init() async {
    // Try a few common init sequences for Y25 / Lefun / JYou
    _debugLogs.add("Starting Y25 Init Sequence (BROADCAST)...");

    // 1. Lefun Magic String: AB 00 04 00 00 00 80 (Bind/Login)
    // Use Broadcast to ensure it hits the right write characteristic
    try {
      final bindCmd = [0xAB, 0x00, 0x04, 0x00, 0x00, 0x00, 0x80];
      final logs = await repository.writeToAllWritable(
        _selectedDevice!.id,
        bindCmd,
      );
      _debugLogs.addAll(logs);
    } catch (e) {
      _debugLogs.add("Bind Broadcast Failed: $e");
    }
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Generic Enable: 01 00
    await sendRawDebugCommand("01 00");
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. Heart Rate Start (Commonly AB 00 05 ... or AB 00 03 ...)
    // Try AB 00 05 00 00 00 80
    await sendRawDebugCommand("AB 00 05 00 00 00 80");

    // 4. Try alternate HR Start
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("AB 00 03 00 00 00 80");

    // 5. Try "Keep Alive" or "Time Set" placeholder
    // AB 00 08 ... (Set Time) - often needed to "unlock" data
    // Format: AB 00 08 [Y] [M] [D] [H] [m] [s] ...
    final now = DateTime.now();
    final year = now.year % 100; // 2 digits
    final cmd =
        "AB 00 08 ${year.toRadixString(16).padLeft(2, '0')} ${now.month.toRadixString(16).padLeft(2, '0')} ${now.day.toRadixString(16).padLeft(2, '0')} ${now.hour.toRadixString(16).padLeft(2, '0')} ${now.minute.toRadixString(16).padLeft(2, '0')} ${now.second.toRadixString(16).padLeft(2, '0')}";
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand(cmd);

    // 7. Set User Profile (Required by some bands for measurement)
    // AB 00 01 [Gender 1=Male] [Age] [Height cm] [Weight kg] ...
    // Example: Male, 30yo, 175cm, 75kg
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("AB 00 01 01 1E B3 4B 00 00");

    // 8. Try 0x73 Protocol Start Measurement (if applicable)
    // 73 15 01 (Start)
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("73 15 01");

    // 9. Try CD Protocol (FitPro / LT716)
    // CD 01 01 01 (Bind?)
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final fitProBind = [0xCD, 0x01, 0x01, 0x01];
      final logs = await repository.writeToAllWritable(
        _selectedDevice!.id,
        fitProBind,
      );
      _debugLogs.addAll(logs);
    } catch (e) {
      _debugLogs.add("FitPro Bind Broadcast Failed: $e");
    }

    // CD 00 11 (Request Data?)
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 11");

    // CD 02 ... (Time Sync) - Proper CD Protocol Time Sync
    // Try CD 02 instead of CD 00 08
    await Future.delayed(const Duration(milliseconds: 500));
    final cdTimeCmd2 =
        "CD 02 ${year.toRadixString(16).padLeft(2, '0')} ${now.month.toRadixString(16).padLeft(2, '0')} ${now.day.toRadixString(16).padLeft(2, '0')} ${now.hour.toRadixString(16).padLeft(2, '0')} ${now.minute.toRadixString(16).padLeft(2, '0')} ${now.second.toRadixString(16).padLeft(2, '0')}";
    await sendRawDebugCommand(cdTimeCmd2);

    // 10. Try FitPro Real-time Measurement Enable
    // CD 00 31 (Enable Real-time)
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 31");

    // Start HR explicitly (CD 00 21 01)
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 21 01");

    // Start SpO2 explicitly (CD 00 23 01) - Added for SpO2 support
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 23 01");

    // Start BP explicitly (CD 00 22 01) - Added just in case
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 22 01");

    // 11. Try "Find Band" command (often wakes it up)
    // CD 00 04
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 04");

    // 12. Try 1A Protocol (Rare FitPro variant)
    // 1A 00 00
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("1A 00 00");

    // 13. Try simple ping (Keep Alive)
    // CD 00 00
    await Future.delayed(const Duration(milliseconds: 500));
    await sendRawDebugCommand("CD 00 00");
  }

  Future<void> triggerHeartRateStart() async {
    _debugLogs.add("Triggering Heart Rate...");
    // Try standard AB protocol for HR
    await sendRawDebugCommand("AB 00 05 00 00 00 80");
    // Try alternate command
    await Future.delayed(const Duration(milliseconds: 300));
    await sendRawDebugCommand("AB 00 03 00 00 00 80");
    // Try 0x73 protocol start
    await Future.delayed(const Duration(milliseconds: 300));
    await sendRawDebugCommand("73 15 01");
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _ipSubscription?.cancel();
    _imageSubscription?.cancel();
    _audioSubscription?.cancel();
    _batterySubscription?.cancel();
    _heartRateSubscription?.cancel();
    _photoTimer?.cancel();
    _silenceTimer?.cancel();
    _healthDataTimer?.cancel();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  Future<void> _describeAndSpeak(Uint8List imageBytes) async {
    try {
      final settings = await settingsRepository.load();
      final useLocal =
          settings.useLocalModels &&
          (settings.localVisionUrl != null &&
              settings.localVisionUrl!.isNotEmpty);
      String description;
      if (useLocal) {
        final visionUrl = settings.localVisionUrl!;
        description = await _describeImageLocal(imageBytes, visionUrl);
      } else {
        final key = settings.geminiApiKey;
        if (key == null || key.isEmpty) {
          _statusMessage = "Gemini API Key requerida";
          notifyListeners();
          return;
        }
        description = await visionRepository.describeImage(
          imageBytes: imageBytes,
          apiKey: key,
          model: 'gemini-2.5-flash',
        );
      }
      _statusMessage = "Descripción: $description";
      notifyListeners();
      await _tts.setLanguage("es-ES");
      await _tts.setSpeechRate(0.5);
      await _tts.speak(description);
      try {
        final deviceId = _selectedDevice?.id ?? _photoDeviceId ?? '';
        if (deviceId.isNotEmpty) {
          final entry = PhotoEntry.newFrom(
            description: description,
            sourceDeviceId: deviceId,
            imageBytes: imageBytes,
          );
          await photoRepository.save(entry);
          _photoJustSaved = true;
          _statusMessage = "Foto guardada";
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Failed to save photo entry: $e");
      }
    } catch (e) {
      _errorMessage = "IA/TTS error: $e";
      notifyListeners();
    }
  }

  void clearPhotoJustSaved() {
    _photoJustSaved = false;
    notifyListeners();
  }

  void _processAudioForSummary(Uint8List pcmBytes) {
    _conversationPcm.addAll(pcmBytes);
    final int16 = Int16List.view(
      pcmBytes.buffer,
      pcmBytes.offsetInBytes,
      pcmBytes.lengthInBytes ~/ 2,
    );
    int sum = 0;
    for (int i = 0; i < int16.length; i++) {
      final v = int16[i].abs();
      sum += v;
    }
    final avg = int16.isNotEmpty ? sum / int16.length : 0.0;

    // Threshold for voice activity
    if (avg > 500) {
      _lastVoiceTs = DateTime.now();
      // Show transient status if not already showing "Listening..."
      // To avoid spamming UI updates, we could check a flag or just update periodically
      // For now, let's just rely on the fact that the timer will pick this up
    }
  }

  void _startSilenceMonitor() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final now = DateTime.now();
      if (_conversationPcm.isNotEmpty) {
        final idleSeconds = now.difference(_lastVoiceTs).inSeconds;

        if (idleSeconds >= _silenceSeconds) {
          _statusMessage = "Silencio detectado. Procesando audio...";
          notifyListeners();
          await _summarizeConversation();
          _conversationPcm.clear();
          _lastVoiceTs = DateTime.now();
        } else {
          // Show countdown periodically to assure user it is working
          if (idleSeconds % 5 == 0) {
            _statusMessage =
                "Escuchando... (${_silenceSeconds - idleSeconds}s para resumen)";
            notifyListeners();
          }
        }
      }
    });
  }

  Future<void> summarizeNow() async {
    if (_conversationPcm.isEmpty) {
      _statusMessage = "No hay audio pendiente para resumir";
      notifyListeners();
      return;
    }
    await _summarizeConversation();
    _conversationPcm.clear();
    _lastVoiceTs = DateTime.now();
  }

  Future<void> _summarizeConversation() async {
    _statusMessage = "Iniciando resumen de audio...";
    notifyListeners();

    // If we have a persistent WebSocket, finish the segment to get results
    _finishWsSegment();

    try {
      final settings = await settingsRepository.load();
      final useLocal =
          settings.useLocalModels &&
          (settings.localAudioUrl != null &&
              settings.localAudioUrl!.isNotEmpty);
      String summary;
      String transcript;
      List<String> suggestions;
      final pcmBytes = Uint8List.fromList(_conversationPcm);
      final wav = _wrapPcmToWav(pcmBytes, sampleRate: 16000, channels: 1);
      if (useLocal) {
        final audioUrl = settings.localAudioUrl!;
        final local = await _summarizeWithLocalBackend(pcmBytes, audioUrl);
        summary = local.summary;
        transcript = local.transcript;
        suggestions = local.suggestions;
      } else {
        final key = settings.geminiApiKey ?? '';
        if (key.isEmpty) {
          _statusMessage = "Gemini API Key requerida";
          notifyListeners();
          return;
        }
        final structured = await _audioStructured
            .transcribeAndSummarizeStructured(
              wavBytes: wav,
              apiKey: key,
              model: 'gemini-2.5-flash',
            );
        summary = structured.summary;
        transcript = structured.transcript;
        suggestions = await audioRepository.generateSuggestionsFromText(
          text: "$summary\n$transcript",
          apiKey: key,
          model: 'gemini-2.5-flash',
        );
      }
      final entry = MemoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        sourceDeviceId: _audioDeviceId ?? _selectedDevice?.id ?? '',
        transcript: transcript,
        summary: summary,
        suggestions: suggestions,
      );
      await memoryRepository.save(entry);
      _statusMessage = "Resumen: $summary";
      notifyListeners();
      await _tts.setLanguage("es-ES");
      await _tts.setSpeechRate(0.55);
      final spoken = suggestions.isNotEmpty
          ? "$summary. Sugerencias: ${suggestions.join('; ')}"
          : summary;
      await _tts.speak(spoken);
    } catch (e) {
      _errorMessage = "Error de resumen de audio: $e";
      notifyListeners();
    }
  }

  Future<String> _describeImageLocal(
    Uint8List imageBytes,
    String visionUrl,
  ) async {
    final uri = _buildEndpointUri(visionUrl, 'vision/frame_b64');
    final body = {
      "session_id": _selectedDevice?.id ?? _photoDeviceId ?? '',
      "image_b64": base64Encode(imageBytes),
    };
    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Local vision error: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body);
    if (json is Map<String, dynamic>) {
      final desc =
          json["description"] ??
          json["summary"] ??
          json["text"] ??
          json["caption"];
      if (desc != null && desc.toString().isNotEmpty) {
        return desc.toString();
      }
    }
    return 'Sin descripción';
  }

  Uri _buildEndpointUri(String baseUrl, String pathSuffix) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.isEmpty ? '' : base.path;
    final separator = basePath.endsWith('/') || basePath.isEmpty ? '' : '/';
    // If the base path already includes the suffix (unlikely but possible), avoid duplication
    // But here we assume user gives BASE URL like http://192.168.1.10:8000
    // and we append vision/frame_b64
    final newPath = '$basePath$separator$pathSuffix';
    return base.replace(path: newPath);
  }

  Future<_LocalAudioSummary> _summarizeWithLocalBackend(
    Uint8List pcmData,
    String audioUrl,
  ) async {
    // Force ws/wss scheme via string manipulation to be absolutely sure
    String wsUrlStr = audioUrl.trim();
    if (wsUrlStr.startsWith('http://')) {
      wsUrlStr = wsUrlStr.replaceFirst('http://', 'ws://');
    } else if (wsUrlStr.startsWith('https://')) {
      wsUrlStr = wsUrlStr.replaceFirst('https://', 'wss://');
    }

    // Parse URI
    var wsUri = Uri.parse(wsUrlStr);

    // Ensure path is correct. If user provided full path to /ws/audio, use it.
    // If user provided base, append /ws/audio.
    if (!wsUri.path.endsWith('/ws/audio')) {
      final basePath = wsUri.path;
      final separator = basePath.endsWith('/') || basePath.isEmpty ? '' : '/';
      final newPath =
          '$basePath$separator'
          'ws/audio';
      wsUri = wsUri.replace(path: newPath);
    }

    _statusMessage = "Conectando al servidor local de audio...";
    notifyListeners();

    debugPrint('Connecting to local audio backend: $wsUri');

    final socket = await WebSocket.connect(wsUri.toString());
    try {
      // Wait for 'ready' message from server
      final iterator = StreamIterator(socket);
      bool ready = false;
      if (await iterator.moveNext()) {
        final message = iterator.current;
        if (message is String) {
          try {
            final data = jsonDecode(message);
            if (data is Map && data["type"] == "ready") {
              ready = true;
            }
          } catch (e) {
            debugPrint("Error parsing ready message: $e");
          }
        }
      }

      if (!ready) {
        throw Exception(
          "Local audio backend did not send 'ready' message or connection closed.",
        );
      }

      final config = {
        "type": "config",
        "session_id": DateTime.now().millisecondsSinceEpoch.toString(),
        "sample_rate": 16000,
        "encoding": "pcm16",
        "language": "es",
      };
      socket.add(utf8.encode(jsonEncode(config)));
      socket.add(pcmData);
      socket.add(utf8.encode(jsonEncode({"type": "end_of_stream"})));

      while (await iterator.moveNext()) {
        final message = iterator.current;
        if (message is String) {
          final data = jsonDecode(message);
          if (data is Map && data["type"] == "final_result") {
            final analysis = data["analysis"];
            if (analysis is Map) {
              final summary = analysis["summary"]?.toString() ?? '';
              final transcriptSegments =
                  analysis["transcript"] as List<dynamic>? ?? const [];
              final transcript = transcriptSegments
                  .map((e) => (e as Map)["text"]?.toString() ?? '')
                  .where((t) => t.isNotEmpty)
                  .join(' ');
              final actionItems =
                  analysis["action_items"] as List<dynamic>? ?? const [];
              final suggestions = actionItems
                  .map((e) => (e as Map)["title"]?.toString() ?? '')
                  .where((t) => t.isNotEmpty)
                  .toList();
              // ignore: unused_local_variable
              final risks = analysis["risks"] as List<dynamic>? ?? const [];
              final risksText = risks
                  .map((r) => r.toString())
                  .where((r) => r.isNotEmpty)
                  .toList();
              final finalSummary = summary.isNotEmpty ? summary : transcript;
              final finalSuggestions = suggestions.isNotEmpty
                  ? suggestions
                  : risksText;
              return _LocalAudioSummary(
                summary: finalSummary,
                transcript: transcript,
                suggestions: finalSuggestions,
              );
            }
          }
        }
      }
      throw Exception('No final_result from local audio backend');
    } finally {
      await socket.close();
    }
  }

  void startDebugListener(String deviceId) {
    _debugSubscription?.cancel();
    // _debugLogs.clear(); // Keep history for debugging context
    _debugLogs.add("--- STARTING DEBUG MONITOR ($deviceId) ---");
    notifyListeners();

    try {
      _debugSubscription = repository
          .monitorAllServices(deviceId)
          .listen(
            (log) {
              if (_debugLogs.length >= 500) {
                // Increased limit for detailed logs
                _debugLogs.removeAt(0);
              }
              _debugLogs.add(log);
              _processDebugData(log);
              notifyListeners();
            },
            onError: (e) {
              _debugLogs.add("Error: $e");
              notifyListeners();
            },
          );
    } catch (e) {
      _debugLogs.add("Failed to start: $e");
      notifyListeners();
    }
  }

  void _processDebugData(String log) {
    if (!log.contains("Data:")) return;
    try {
      final parts = log.split("Data: ");
      if (parts.length < 2) return;

      final uuidPart = parts[0].toLowerCase(); // e.g. "[00002a37-...] "
      final hexStr = parts[1].trim();
      if (hexStr.isEmpty) return;

      // Update status immediately to show aliveness
      // _statusMessage = "Rx: ${hexStr.length > 20 ? hexStr.substring(0, 20) + '...' : hexStr}";
      // notifyListeners();

      final bytes = hexStr
          .split(' ')
          .map((e) => int.parse(e, radix: 16))
          .toList();

      bool handled = false;

      // 1. Check for Standard BLE Heart Rate (UUID 0x2A37)
      if (uuidPart.contains("2a37")) {
        // Standard BLE HR Format: Flags (1 byte) + Value (1 or 2 bytes)
        // Flags bit 0: 0=uint8, 1=uint16
        if (bytes.isNotEmpty) {
          final flags = bytes[0];
          final isUint16 = (flags & 0x01) != 0;
          if (isUint16 && bytes.length >= 3) {
            final hr = bytes[1] + (bytes[2] << 8);
            _heartRate = hr;
            _statusMessage = "Std HR (16): $hr BPM";
          } else if (!isUint16 && bytes.length >= 2) {
            final hr = bytes[1];
            _heartRate = hr;
            _statusMessage = "Std HR (8): $hr BPM";
          }
          _debugLogs.add("Standard HR Update: $_heartRate");
          handled = true;
          notifyListeners();
          return;
        }
      }

      // 2. Y25 / Lefun Protocol (Magic Byte 0xAB)
      if (bytes.isNotEmpty && bytes[0] == 0xAB) {
        // AB 00 06 ... (Battery Info)
        if (bytes.length >= 7 && bytes[2] == 0x06) {
          final battery = bytes[4];
          if (battery >= 0 && battery <= 100) {
            _batteryLevel = battery;
            _statusMessage = "Battery: $battery%";
            _debugLogs.add("Parsed Battery: $battery%");
            handled = true;
          }
        }

        // AB 00 0A ... (Stats: Steps, Cal, Dist)
        if (bytes.length >= 17 && bytes[2] == 0x0A) {
          final stepsVal = (bytes[4] << 16) | (bytes[5] << 8) | bytes[6];
          _steps = stepsVal;
          final calVal = (bytes[7] << 16) | (bytes[8] << 8) | bytes[9];
          _calories = calVal;
          final distVal = (bytes[10] << 16) | (bytes[11] << 8) | bytes[12];
          _distanceKm = distVal / 1000.0;
          _statusMessage = "Steps: $_steps";
          _debugLogs.add(
            "Parsed Stats: Steps=$_steps, Cal=$_calories, Dist=$_distanceKm",
          );
          handled = true;
        }

        // AB 00 05 ... (Measurement Data)
        if (bytes.length >= 6 &&
            (bytes[2] == 0x05 || bytes[2] == 0x03 || bytes[2] == 0x11)) {
          // Try multiple offsets for HR
          // Usually byte 4 or 5
          int hr = 0;
          if (bytes[4] > 30 && bytes[4] < 220)
            hr = bytes[4];
          else if (bytes.length > 5 && bytes[5] > 30 && bytes[5] < 220)
            hr = bytes[5];

          if (hr > 0) {
            _heartRate = hr;
            _statusMessage = "Y25 HR: $hr BPM";
            _debugLogs.add("Parsed HR (AB): $hr");
            handled = true;
          }

          if (bytes.length >= 7) {
            final spo2 = bytes[6];
            if (spo2 >= 80 && spo2 <= 100) {
              _bloodOxygen = spo2;
              _debugLogs.add("Parsed SpO2 (AB): $spo2");
            }
          }
        }
      }

      // 3. Protocol 0x73 (Detected in logs)
      if (bytes.isNotEmpty && bytes[0] == 0x73) {
        // 73 01 ... (Ack / Connected)
        if (bytes.length >= 2 && bytes[1] == 0x01) {
          _statusMessage = "Y25 Connected (Ack)";
          _debugLogs.add("Y25 Ack Received (73 01)");
          handled = true;
        }
        // 73 2C ... (Heart Rate?)
        if (bytes.length >= 3 && bytes[1] == 0x2C) {
          final hr = bytes[2];
          if (hr > 0) {
            if (hr > 40 && hr < 220) {
              _heartRate = hr;
              _statusMessage = "Y25(73) HR: $hr BPM";
              _debugLogs.add("Parsed HR (73): $hr");
              handled = true;
            } else if (bytes.length > 3 && bytes[3] > 40 && bytes[3] < 220) {
              // Maybe byte[3] is the value?
              _heartRate = bytes[3];
              _statusMessage = "Y25(73) HR: ${bytes[3]} BPM";
              _debugLogs.add("Parsed HR (73-alt): ${bytes[3]}");
              handled = true;
            } else {
              _debugLogs.add("Ignored HR (73): $hr (Status/Invalid)");
            }
          }
        }
        // 73 2B ... (SPO2?)
        if (bytes.length >= 3 && bytes[1] == 0x2B) {
          final spo2 = bytes[2];
          if (spo2 > 0 && spo2 <= 100) {
            if (spo2 >= 80) {
              _bloodOxygen = spo2;
              _debugLogs.add("Parsed SpO2 (73): $spo2");
              handled = true;
            } else if (bytes.length > 3 && bytes[3] >= 80 && bytes[3] <= 100) {
              _bloodOxygen = bytes[3];
              _debugLogs.add("Parsed SpO2 (73-alt): ${bytes[3]}");
              handled = true;
            } else if (bytes.length > 4 && bytes[4] >= 80 && bytes[4] <= 100) {
              _bloodOxygen = bytes[4];
              _debugLogs.add("Parsed SpO2 (73-byte4): ${bytes[4]}");
              handled = true;
            } else {
              // Handle Status Codes (32/33 likely "Measuring" or "Sensor Contact")
              if (spo2 == 32 || spo2 == 33) {
                _statusMessage = "SpO2: Midiendo... (Code $spo2)";
                _debugLogs.add("SpO2 Status: Measuring ($spo2)");
              } else {
                _debugLogs.add("Ignored SpO2 (73): $spo2 (Status/Invalid)");
              }
            }
          }
        }
      }

      // 4. Protocol 0xBC / 0xCD (FitPro / LT716)
      if (bytes.isNotEmpty && (bytes[0] == 0xBC || bytes[0] == 0xCD)) {
        // CD 01 01 01 (Response to Bind?)
        if (bytes.length >= 4 && bytes[1] == 0x01 && bytes[2] == 0x01) {
          _statusMessage = "FitPro Connected";
          _debugLogs.add("FitPro Bind OK");
          handled = true;
        }
        // BC 02 01 00 ... (Bind OK / Response)
        if (bytes.length >= 3 && bytes[1] == 0x02) {
          _debugLogs.add("Received BC Protocol Response (Bind OK?)");
          handled = true;
        }
        // Data Packets (Often start with CD 00 ...)
        // If it's a stats packet, it might be longer.
        if (bytes.length > 5) {
          // Heuristic: Look for HR-like values
          for (int i = 1; i < bytes.length; i++) {
            if (bytes[i] > 40 && bytes[i] < 200) {
              // Only update if we don't have a valid HR yet or it changed
              if (_heartRate == null || (_heartRate != bytes[i])) {
                // _heartRate = bytes[i]; // Too risky to auto-assign without ID
                // _debugLogs.add("Potential HR in BC: ${bytes[i]} (at index $i)");
              }
            }
          }
        }
      }

      // 6. Fallback: Embedded Scan (if not strictly handled or just to be safe)
      if (!handled && bytes.length > 2) {
        // Look for sequence [0x73, 0x2C, VALUE] anywhere
        for (int i = 0; i < bytes.length - 2; i++) {
          if (bytes[i] == 0x73 && bytes[i + 1] == 0x2C) {
            final hr = bytes[i + 2];
            if (hr > 30 && hr < 220) {
              _heartRate = hr;
              _statusMessage = "Found HR: $hr";
              _debugLogs.add("Scanned HR: $hr");
              handled = true;
            }
          }
          if (bytes[i] == 0x73 && bytes[i + 1] == 0x2B) {
            final spo2 = bytes[i + 2];
            if (spo2 > 80 && spo2 <= 100) {
              _bloodOxygen = spo2;
              _debugLogs.add("Scanned SPO2: $spo2");
            }
          }
        }
      }

      // 7. Universal HR Finder (Last Resort for "Truncated" feeling)
      // If we still haven't handled it, and it's a "Notify" characteristic (implied by context)
      // Check if it's a simple 1-2 byte packet that might be HR
      if (!handled && bytes.length <= 4) {
        if (bytes.length == 2 &&
            bytes[0] == 0 &&
            bytes[1] > 40 &&
            bytes[1] < 200) {
          _heartRate = bytes[1];
          _debugLogs.add("Inferred HR (Short): ${bytes[1]}");
          handled = true;
        }
      }

      // 8. Ultimate Fallback: Just show the raw data in status if it looks interesting
      if (!handled) {
        if (bytes.isNotEmpty) {
          _statusMessage = "Raw: ${bytes.take(5).join(' ')}...";
          _debugLogs.add("Unparsed: $bytes");
        } else {
          _statusMessage = "Empty data packet";
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Parse Error: $e");
      _statusMessage = "Parse Error: $e";
      notifyListeners();
    }
  }

  Uint8List _wrapPcmToWav(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final dataSize = pcm.lengthInBytes;
    final totalSize = 36 + dataSize;
    final header = BytesBuilder();
    header.add(utf8.encode('RIFF'));
    header.add(_le32(totalSize));
    header.add(utf8.encode('WAVE'));
    header.add(utf8.encode('fmt '));
    header.add(_le32(16));
    header.add(_le16(1));
    header.add(_le16(channels));
    header.add(_le32(sampleRate));
    header.add(_le32(byteRate));
    header.add(_le16(blockAlign));
    header.add(_le16(16));
    header.add(utf8.encode('data'));
    header.add(_le32(dataSize));
    header.add(pcm);
    return header.toBytes();
  }

  Uint8List _le16(int v) {
    return Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]);
  }

  Uint8List _le32(int v) {
    return Uint8List.fromList([
      v & 0xFF,
      (v >> 8) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 24) & 0xFF,
    ]);
  }

  Future<void> requestBackgroundPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
      Permission.microphone,
    ].request();
  }
}

class _LocalAudioSummary {
  final String summary;
  final String transcript;
  final List<String> suggestions;
  _LocalAudioSummary({
    required this.summary,
    required this.transcript,
    required this.suggestions,
  });
}
