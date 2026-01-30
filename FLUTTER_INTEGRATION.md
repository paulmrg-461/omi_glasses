# Guía de Integración Flutter para Omi Glasses

Esta guía detalla cómo conectar tu propia aplicación Flutter a las Omi Glasses (versión firmware v2.1.1+) para:
1.  Conectarse vía Bluetooth Low Energy (BLE).
2.  Recibir y reproducir audio (micrófono de las gafas).
3.  Tomar fotos y recibirlas en la app.

## 1. Dependencias Necesarias

Agrega las siguientes dependencias a tu `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.31.0  # Para conexión Bluetooth
  permission_handler: ^11.0.0 # Para permisos de Bluetooth/Ubicación
  opus_flutter: ^3.0.3        # Para decodificar el audio de las gafas
  flutter_sound: ^9.0.0       # (Opcional) Para reproducir el audio PCM
```

## 2. UUIDs del Protocolo Omi

Las Omi Glasses utilizan los siguientes identificadores (UUIDs) para comunicarse:

```dart
class OmiConstants {
  // Servicio Principal
  static const String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";

  // Audio (Gafas -> App)
  static const String audioDataUuid = "19B10001-E8F2-537E-4F6C-D104768A1214"; // Notify
  static const String audioCodecUuid = "19B10002-E8F2-537E-4F6C-D104768A1214"; // Read

  // Fotos (Gafas -> App)
  static const String photoDataUuid = "19B10005-E8F2-537E-4F6C-D104768A1214"; // Notify
  static const String photoControlUuid = "19B10006-E8F2-537E-4F6C-D104768A1214"; // Write
}
```

## 3. Conexión a las Gafas

El dispositivo se anuncia como **"OMI Glass"**.

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<BluetoothDevice?> scanAndConnect() async {
  // 1. Iniciar escaneo
  await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

  BluetoothDevice? omiDevice;
  
  // 2. Buscar dispositivo "OMI Glass"
  FlutterBluePlus.scanResults.listen((results) {
    for (ScanResult result in results) {
      if (result.device.platformName == "OMI Glass") {
        omiDevice = result.device;
        FlutterBluePlus.stopScan();
        break;
      }
    }
  });

  // Esperar a encontrarlo...
  await Future.delayed(const Duration(seconds: 6));

  if (omiDevice != null) {
    // 3. Conectar
    await omiDevice!.connect();
    print("Conectado a Omi Glass!");
    return omiDevice;
  }
  
  return null;
}
```

## 4. Escuchar Audio (Micrófono)

Las gafas envían audio comprimido en formato **Opus** para ahorrar batería y ancho de banda. No puedes reproducirlo directamente; debes decodificarlo a PCM (WAV) primero.

### Paso A: Suscribirse a la característica de Audio

```dart
Future<void> listenToAudio(BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();
  
  var service = services.firstWhere((s) => s.uuid.toString().toUpperCase() == OmiConstants.serviceUuid);
  var audioChar = service.characteristics.firstWhere((c) => c.uuid.toString().toUpperCase() == OmiConstants.audioDataUuid);

  await audioChar.setNotifyValue(true);
  
  audioChar.lastValueStream.listen((value) {
    if (value.isNotEmpty) {
      processAudioPacket(value);
    }
  });
}
```

### Paso B: Procesar y Decodificar Audio

Cada paquete tiene un encabezado de 3 bytes y luego los datos Opus.

```dart
import 'dart:typed_data';
import 'package:opus_flutter/opus_flutter.dart';

// Inicializar decodificador Opus (16kHz, mono)
final OpusStreamDecoder _decoder = OpusStreamDecoder(
  sampleRate: 16000, 
  channels: 1
);

void processAudioPacket(List<int> packet) {
  // El paquete tiene formato: [ID_BAJO, ID_ALTO, SUB_ID, ...OPUS_DATA...]
  if (packet.length <= 3) return;

  // Extraer datos Opus (saltar los primeros 3 bytes de encabezado)
  Uint8List opusData = Uint8List.fromList(packet.sublist(3));

  // Decodificar a PCM (Audio crudo)
  try {
    Uint8List pcmData = _decoder.decode(opusData);
    
    // AQUÍ TIENES EL AUDIO RAW (PCM 16-bit 16kHz Mono)
    // Puedes:
    // 1. Guardarlo en un archivo .wav
    // 2. Reproducirlo en tiempo real (buffer)
    // 3. Enviarlo a una API (Whisper, etc.)
    playAudioChunk(pcmData); 
    
  } catch (e) {
    print("Error decodificando Opus: $e");
  }
}
```

## 5. Tomar Fotos y Ver Video

**Nota:** El "video" en BLE es en realidad una secuencia rápida de fotos. No esperes 30fps; es más bien para tomar capturas.

### Paso A: Solicitar una Foto

Escribe en la característica de control (`photoControlUuid`).

```dart
Future<void> takePhoto(BluetoothDevice device) async {
  // ... obtener servicio y características igual que arriba ...
  var controlChar = service.characteristics.firstWhere((c) => c.uuid.toString().toUpperCase() == OmiConstants.photoControlUuid);
  
  // Enviar comando para tomar foto (puedes enviar diferentes valores según el firmware, 
  // generalmente escribir cualquier byte inicia la captura o controla el flash)
  await controlChar.write([0x01]); 
  print("Solicitud de foto enviada");
}
```

### Paso B: Recibir y Reconstruir la Foto

La foto es grande, así que llega en muchos paquetes pequeños ("chunks"). Debes unirlos.

```dart
List<int> photoBuffer = [];
bool isReceivingPhoto = false;

void setupPhotoListener(BluetoothCharacteristic photoDataChar) async {
  await photoDataChar.setNotifyValue(true);
  
  photoDataChar.lastValueStream.listen((value) {
    if (value.length < 2) return;
    
    // Los primeros 2 bytes son el índice del chunk
    int chunkIndex = value[0] | (value[1] << 8);
    
    // El firmware envía 0xFFFF (65535) para indicar FIN de la foto
    if (chunkIndex == 0xFFFF) {
      print("Foto completa recibida! Tamaño: ${photoBuffer.length} bytes");
      saveAndShowImage(Uint8List.fromList(photoBuffer));
      photoBuffer.clear();
      isReceivingPhoto = false;
    } else {
      // Es un pedazo de la foto, agrégalo al buffer
      if (!isReceivingPhoto) {
         print("Iniciando recepción de foto...");
         isReceivingPhoto = true;
         photoBuffer.clear();
      }
      // Agregar los datos (saltando los 2 bytes de índice)
      photoBuffer.addAll(value.sublist(2));
    }
  });
}
```

## Resumen del Flujo

1.  **Conectar** a "OMI Glass".
2.  **Audio:** Suscribirse a `19B10001...`. Recibir bytes -> Quitar 3 bytes header -> Decodificar Opus -> Reproducir PCM.
3.  **Foto:** Suscribirse a `19B10005...`. Escribir a `19B10006...` para pedir foto. Acumular bytes hasta recibir índice `0xFFFF`. Mostrar imagen JPEG.
