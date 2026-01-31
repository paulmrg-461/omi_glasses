# Guía de Integración Flutter para Omi Glasses

Esta guía detalla cómo conectar tu propia aplicación Flutter a las Omi Glasses (versión firmware v2.1.1+) para:
1.  Conectarse vía Bluetooth Low Energy (BLE).
2.  Recibir y reproducir audio (micrófono de las gafas).
3.  Tomar fotos y recibirlas en la app.
4.  **[NUEVO]** Configurar WiFi para Streaming de Video y Audio.

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
  # Para streaming MJPEG (Video)
  flutter_mjpeg: ^2.1.0 
```

## 2. UUIDs del Protocolo Omi

Las Omi Glasses utilizan los siguientes identificadores (UUIDs) para comunicarse:

```dart
class OmiConstants {
  // Servicio Principal
  static const String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";

  // Audio (Gafas -> App via BLE)
  static const String audioDataUuid = "19B10001-E8F2-537E-4F6C-D104768A1214"; // Notify
  static const String audioCodecUuid = "19B10002-E8F2-537E-4F6C-D104768A1214"; // Read

  // Fotos (Gafas -> App via BLE)
  static const String photoDataUuid = "19B10005-E8F2-537E-4F6C-D104768A1214"; // Notify
  static const String photoControlUuid = "19B10006-E8F2-537E-4F6C-D104768A1214"; // Write
  
  // WiFi Provisioning (App -> Gafas) - NUEVO
  static const String wifiSsidUuid = "19B10003-E8F2-537E-4F6C-D104768A1214"; // Write
  static const String wifiPasswordUuid = "19B10004-E8F2-537E-4F6C-D104768A1214"; // Write
  static const String ipAddressUuid = "19B10008-E8F2-537E-4F6C-D104768A1214"; // Read/Notify
}
```

## 3. Conexión a las Gafas

### Problemas Comunes de Detección (Troubleshooting)

Si tu app dejó de reconocer las gafas después de una actualización de firmware, es muy probable que se deba a la **caché de Bluetooth** del sistema operativo o a cambios en el paquete de anuncio.

**Pasos rápidos para solucionar:**
1.  **Apaga y enciende el Bluetooth** de tu celular (esto limpia la caché inmediata).
2.  Si alguna vez emparejaste las gafas manualmente en los Ajustes de Android/iOS, **"Olvida" el dispositivo**.
3.  Reinicia la app.

### Método de Escaneo Robusto (Recomendado)

En lugar de filtrar solo por nombre (que puede no aparecer en el primer paquete de datos), es más seguro filtrar por el **Service UUID**.

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<BluetoothDevice?> scanAndConnect() async {
  BluetoothDevice? omiDevice;

  // 1. Iniciar escaneo filtrando por el Servicio Principal de OMI
  // Esto es mucho más rápido y confiable que buscar por nombre string.
  await FlutterBluePlus.startScan(
    timeout: const Duration(seconds: 10),
    withServices: [Guid(OmiConstants.serviceUuid)], // Filtro por UUID
  );

  // 2. Escuchar resultados
  var subscription = FlutterBluePlus.scanResults.listen((results) {
    for (ScanResult result in results) {
        // Opcional: Verificar nombre también si es necesario
        // Nota: result.advertisementData.localName puede estar vacío inicialmente en algunos dispositivos
        print("Dispositivo encontrado: ${result.device.remoteId}");
        
        omiDevice = result.device;
        FlutterBluePlus.stopScan();
        break;
    }
  });

  // Esperar resultado...
  await Future.delayed(const Duration(seconds: 10));
  await subscription.cancel();

  if (omiDevice != null) {
    // 3. Conectar
    // 'autoflush: false' ayuda a evitar problemas de caché en Android al reconectar
    await omiDevice!.connect(autoConnect: false);
    
    // IMPORTANTE: En Android, es necesario descubrir servicios después de conectar
    // para limpiar la caché de servicios antiguos.
    if (Platform.isAndroid) {
        await omiDevice!.discoverServices();
    }
    
    print("Conectado a Omi Glass!");
    return omiDevice;
  }
  
  return null;
}
```

**Nota sobre Android:** Android guarda agresivamente la estructura de servicios (GATT table). Si el firmware cambió (nuevos servicios WiFi), Android podría estar intentando usar la tabla antigua. Llamar a `discoverServices()` fuerza una actualización.

## 4. Configurar WiFi para Streaming (Video/Audio)

Para habilitar el streaming de alta velocidad (video MJPEG), debes enviar las credenciales WiFi a las gafas.

```dart
Future<void> connectGlassesToWifi(BluetoothDevice device, String ssid, String password) async {
  List<BluetoothService> services = await device.discoverServices();
  var service = services.firstWhere((s) => s.uuid.toString().toUpperCase() == OmiConstants.serviceUuid);
  
  // 1. Escribir SSID
  var ssidChar = service.characteristics.firstWhere((c) => c.uuid.toString().toUpperCase() == OmiConstants.wifiSsidUuid);
  await ssidChar.write(utf8.encode(ssid));
  
  // 2. Escribir Password (esto desencadena la conexión)
  var passChar = service.characteristics.firstWhere((c) => c.uuid.toString().toUpperCase() == OmiConstants.wifiPasswordUuid);
  await passChar.write(utf8.encode(password));
  
  print("Credenciales WiFi enviadas. Las gafas intentarán conectarse.");
}

Future<String?> listenForIpAddress(BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();
  var service = services.firstWhere((s) => s.uuid.toString().toUpperCase() == OmiConstants.serviceUuid);
  var ipChar = service.characteristics.firstWhere((c) => c.uuid.toString().toUpperCase() == OmiConstants.ipAddressUuid);

  await ipChar.setNotifyValue(true);
  
  String? ipAddress;
  ipChar.lastValueStream.listen((value) {
    if (value.isNotEmpty) {
      ipAddress = String.fromCharCodes(value);
      print("IP Address recibida: $ipAddress");
    }
  });
  
  // También puedes leer el valor directamente si ya está conectado
  var val = await ipChar.read();
  if (val.isNotEmpty) {
      return String.fromCharCodes(val);
  }
  return null;
}
```

## 5. Streaming de Video y Fotos

Una vez conectadas a la misma red WiFi que tu teléfono, las gafas iniciarán un servidor web.
Puedes obtener la IP suscribiéndote a la característica `ipAddressUuid`.

### Streaming de Video (MJPEG)

URL: `http://<IP_GAFAS>/stream`

```dart
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

// En tu Widget build:
Mjpeg(
  isLive: true,
  stream: 'http://192.168.1.50/stream', // Usa la IP obtenida
)
```

### Captura de Fotos (Snapshot)

Puedes obtener una foto de alta resolución bajo demanda sin detener el stream.

URL: `http://<IP_GAFAS>/snapshot`

```dart
Image.network('http://192.168.1.50/snapshot');
```

## 6. Escuchar Audio (BLE Legacy)

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

### Paso B: Decodificar Opus

El paquete de audio contiene 3 bytes de cabecera y N bytes de audio Opus.

```dart
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

// Inicializar decodificador (16kHz, Mono)
final StreamAudioDecoder _decoder = opus_flutter.StreamAudioDecoder(
  sampleRate: 16000,
  channels: 1,
);

void processAudioPacket(List<int> packet) {
  // Ignorar cabecera (primeros 3 bytes: index + subindex)
  if (packet.length <= 3) return;
  
  Uint8List opusData = Uint8List.fromList(packet.sublist(3));
  
  // Decodificar a PCM (Int16)
  Uint8List pcmData = _decoder.decode(input: opusData);
  
  // Reproducir pcmData usando flutter_sound o similar...
}
```
