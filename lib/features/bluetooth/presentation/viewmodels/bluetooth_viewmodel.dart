import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  // Audio State
  FlutterSoundPlayer? _audioPlayer;
  bool _isAudioEnabled = false;
  bool get isAudioEnabled => _isAudioEnabled;
  final FlutterTts _tts = FlutterTts();
  final List<int> _conversationPcm = [];
  DateTime _lastVoiceTs = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _silenceTimer;
  int _silenceMinutes = 2;

  // Role assignments
  String? _audioDeviceId;
  String? get audioDeviceId => _audioDeviceId;
  String? _photoDeviceId;
  String? get photoDeviceId => _photoDeviceId;
  Timer? _photoTimer;

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

  BluetoothViewModel({
    required this.repository,
    required this.settingsRepository,
    required this.visionRepository,
    required this.audioRepository,
    required this.memoryRepository,
    required this.photoRepository,
  });

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
        _connectedDeviceServices = await repository.discoverServices(deviceId);

        // Start monitoring battery automatically
        startBatteryListener();

        // Auto-assign photo source if capable and not set yet
        if (_photoDeviceId == null) {
          final canPhoto = await repository.isPhotoCapable(deviceId);
          if (canPhoto) {
            await setPhotoSource(deviceId);
          }
        }
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

  Future<void> disconnect([String? deviceId]) async {
    // If no deviceId provided, try to disconnect the selected one
    final targetId = deviceId ?? _selectedDevice?.id;

    if (targetId != null) {
      // Remove from list
      _connectedDevices.removeWhere((d) => d.id == targetId);

      // If it was the selected device, clear selection
      if (_selectedDevice?.id == targetId) {
        _selectedDevice = null;
        _connectedDeviceServices = [];
      }

      // Cleanup roles if the device was assigned
      if (_audioDeviceId == targetId) {
        await stopAudio();
        _audioDeviceId = null;
      }
      if (_photoDeviceId == targetId) {
        _photoTimer?.cancel();
        _photoTimer = null;
        _photoDeviceId = null;
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
    final targetId = _photoDeviceId ?? _selectedDevice?.id;
    if (targetId == null) return;

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
    final targetId = _photoDeviceId ?? _selectedDevice?.id;
    if (targetId == null) return;

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

  Future<void> startAudio() async {
    if (_selectedDevice == null) return;

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
          .startAudioStream(_selectedDevice!.id)
          .listen(
            (data) {
              if (_audioPlayer != null && _audioPlayer!.isPlaying) {
                // feed the player
                // debugPrint("Feeding ${data.length} bytes to audio player");
                _audioPlayer!.uint8ListSink!.add(data);
              }
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
    // Start listening to images from the photo device
    startImageListenerFor(deviceId);
    // Restart timer
    _photoTimer?.cancel();
    _photoTimer = Timer.periodic(interval, (_) {
      triggerPhotoFor(deviceId);
    });
    _statusMessage = "Photo timer started (every ${interval.inSeconds}s)";
    notifyListeners();
  }

  Future<void> setAudioSource(String deviceId) async {
    await startAudioFrom(deviceId);
    _statusMessage = "Audio source set";
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _ipSubscription?.cancel();
    _imageSubscription?.cancel();
    _audioSubscription?.cancel();
    _batterySubscription?.cancel();
    _photoTimer?.cancel();
    _silenceTimer?.cancel();
    _audioPlayer?.closePlayer();
    super.dispose();
  }

  Future<void> _describeAndSpeak(Uint8List imageBytes) async {
    try {
      final settings = await settingsRepository.load();
      final key = settings.geminiApiKey;
      if (key == null || key.isEmpty) {
        _statusMessage = "Gemini API Key requerida";
        notifyListeners();
        return;
      }
      final description = await visionRepository.describeImage(
        imageBytes: imageBytes,
        apiKey: key,
        model: 'gemini-2.5-flash',
      );
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
        }
      } catch (e) {
        debugPrint("Failed to save photo entry: $e");
      }
    } catch (e) {
      _errorMessage = "Gemini/TTS error: $e";
      notifyListeners();
    }
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
    if (avg > 600) {
      _lastVoiceTs = DateTime.now();
    }
  }

  void _startSilenceMonitor() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final idleFor = DateTime.now().difference(_lastVoiceTs).inMinutes;
      if (idleFor >= _silenceMinutes && _conversationPcm.isNotEmpty) {
        await _summarizeConversation();
        _conversationPcm.clear();
        _lastVoiceTs = DateTime.now();
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
    try {
      final settings = await settingsRepository.load();
      final key = settings.geminiApiKey ?? '';
      if (key.isEmpty) {
        _statusMessage = "Gemini API Key requerida";
        notifyListeners();
        return;
      }
      final wav = _wrapPcmToWav(
        Uint8List.fromList(_conversationPcm),
        sampleRate: 16000,
        channels: 1,
      );
      final structured = await _audioStructured
          .transcribeAndSummarizeStructured(
            wavBytes: wav,
            apiKey: key,
            model: 'gemini-2.5-flash',
          );
      final summary = structured.summary;
      final transcript = structured.transcript;
      final suggestions = await audioRepository.generateSuggestionsFromText(
        text: "$summary\n$transcript",
        apiKey: key,
        model: 'gemini-2.5-flash',
      );
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
