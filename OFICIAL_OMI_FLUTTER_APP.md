toolName: view_folder
            
status: success
          
c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib
          

        
            
toolName: view_folder
            
status: success
          
c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services
          

        
            
toolName: view_folder
            
status: success
          
c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\utils
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\discovery\bluetooth_discoverer.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\omi_connection.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\transports\ble_transport.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\backend\schema\bt_device\bt_device.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\omi_connection.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\device_connection.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\device_connection.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\models.dart
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\utils\image\image_utils.dart
          

        
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\models.dart
          

        
            
toolName: search_codebase
            
status: success
          
query: code related to sending audio to Omi glasses or playing audio on Omi glasses
          

        
            
toolName: search_codebase
            
status: success
          
query: code related to video streaming or continuous image capture from Omi glasses
          

        
            
toolName: view_files
            
status: success
          
            
filePath: c:\Users\paulm\Documents\dev-projects\IAAplicada\OMIGlasses\omi\app\lib\services\devices\transports\ble_transport.dart
          
¡Claro! Aquí tienes una guía completa en formato Markdown para integrar las Omi Glasses en tu propia aplicación Flutter. Esta guía cubre la conexión BLE, transmisión de audio y captura de imágenes/video, basada en la arquitectura oficial de Omi.

***

# Guía de Integración Omi Glasses para Flutter

Esta guía detalla cómo conectar tu aplicación Flutter a las Omi Glasses para interactuar con sus sensores, micrófono y cámara utilizando Bluetooth Low Energy (BLE).

## 1. Configuración del Proyecto

### Dependencias
Añade las siguientes dependencias a tu `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_blue_plus: ^1.30.0 # Para comunicación BLE
  permission_handler: ^11.0.0 # Para permisos de Bluetooth
```

### Permisos (Android/iOS)

**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS (`ios/Runner/Info.plist`):**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>La app necesita Bluetooth para conectar con las Omi Glasses.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>La app necesita Bluetooth para conectar con las Omi Glasses.</string>
```

---

## 2. Definición de UUIDs

Las Omi Glasses utilizan UUIDs específicos para sus servicios y características. Defínelos en tu código:

```dart
class OmiConstants {
  // Servicio Principal
  static const String omiServiceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';

  // Audio (Micrófono)
  static const String audioDataStreamUuid = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String audioCodecUuid = '19b10002-e8f2-537e-4f6c-d104768a1214';

  // Cámara / Video
  static const String imageDataStreamUuid = '19b10005-e8f2-537e-4f6c-d104768a1214';
  static const String imageControlUuid = '19b10006-e8f2-537e-4f6c-d104768a1214';
}
```

---

## 3. Conexión a las Gafas

Utiliza `flutter_blue_plus` para escanear y conectar.

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Future<BluetoothDevice?> findOmiGlasses() async {
  BluetoothDevice? omiDevice;
  
  // Iniciar escaneo filtrando por el servicio de Omi
  await FlutterBluePlus.startScan(
    withServices: [Guid(OmiConstants.omiServiceUuid)],
    timeout: const Duration(seconds: 10),
  );

  FlutterBluePlus.scanResults.listen((results) {
    for (ScanResult r in results) {
      if (r.device.platformName.contains("Omi")) { // O verifica el UUID
        omiDevice = r.device;
        FlutterBluePlus.stopScan();
        break;
      }
    }
  });
  
  return omiDevice;
}

Future<void> connectToOmi(BluetoothDevice device) async {
  await device.connect();
  
  // Solicitar MTU alto para mejor transferencia de imágenes/audio
  if (Platform.isAndroid) {
    await device.requestMtu(512);
  }
  
  await device.discoverServices();
}
```

---

## 4. Escuchar Audio (Micrófono)

Para recibir audio desde el micrófono de las gafas, suscríbete a la característica de flujo de audio.

```dart
Future<void> listenToAudio(BluetoothDevice device) async {
  List<BluetoothService> services = await device.discoverServices();
  var service = services.firstWhere((s) => s.uuid.toString() == OmiConstants.omiServiceUuid);
  var char = service.characteristics.firstWhere((c) => c.uuid.toString() == OmiConstants.audioDataStreamUuid);

  await char.setNotifyValue(true);
  char.lastValueStream.listen((data) {
    // 'data' contiene bytes de audio (usualmente Opus o PCM8)
    // Aquí puedes procesar, guardar o enviar el audio a una API de STT
    print("Recibidos ${data.length} bytes de audio");
  });
}
```

### Nota sobre "Hablar desde las gafas" (Output)
Las Omi Glasses funcionan como un dispositivo de audio Bluetooth estándar (A2DP/HFP) para la salida de audio (música, llamadas, TTS).
*   **Para enviar audio a las gafas:** No necesitas código BLE especial. Simplemente empareja las gafas en la configuración de Bluetooth del sistema operativo. Tu app de Flutter usará automáticamente las gafas como salida de audio si el sistema lo tiene seleccionado.

---

## 5. Ver Video o Tomar Fotos

El sistema de cámara funciona enviando comandos de control y recibiendo fragmentos de imagen que deben ser reensamblados.

### Paso A: Suscribirse al Flujo de Imágenes

```dart
import 'dart:typed_data';

void startImageListener(BluetoothDevice device) async {
  var service = (await device.discoverServices()).firstWhere((s) => s.uuid.toString() == OmiConstants.omiServiceUuid);
  var imageChar = service.characteristics.firstWhere((c) => c.uuid.toString() == OmiConstants.imageDataStreamUuid);

  List<int> imageBuffer = [];
  
  await imageChar.setNotifyValue(true);
  imageChar.lastValueStream.listen((data) {
    if (data.length < 2) return;

    // Los primeros 2 bytes son el índice del frame
    int frameIndex = data[0] | (data[1] << 8);

    if (frameIndex == 0xFFFF) {
      // Marcador de fin de imagen: Procesar el buffer completo
      if (imageBuffer.isNotEmpty) {
        final finalImage = Uint8List.fromList(imageBuffer);
        print("Imagen completa recibida: ${finalImage.length} bytes");
        // Mostrar imagen usando Image.memory(finalImage)
        imageBuffer.clear();
      }
    } else {
      // Añadir datos al buffer (saltando los 2 bytes de header)
      if (data.length > 2) {
        imageBuffer.addAll(data.sublist(2));
      }
    }
  });
}
```

### Paso B: Enviar Comando de Captura

Para "Ver video", puedes solicitar fotos continuamente o usar el modo de captura periódica.

```dart
Future<void> takePhoto(BluetoothDevice device) async {
  var service = (await device.discoverServices()).firstWhere((s) => s.uuid.toString() == OmiConstants.omiServiceUuid);
  var controlChar = service.characteristics.firstWhere((c) => c.uuid.toString() == OmiConstants.imageControlUuid);

  // Enviar comando para tomar 1 foto
  // Comando: [-1] (o 0xFF) para una sola foto
  await controlChar.write([-1]); 
}

Future<void> startVideoFeed(BluetoothDevice device) async {
  var service = (await device.discoverServices()).firstWhere((s) => s.uuid.toString() == OmiConstants.omiServiceUuid);
  var controlChar = service.characteristics.firstWhere((c) => c.uuid.toString() == OmiConstants.imageControlUuid);

  // Comando: [5] para tomar una foto cada 5 segundos (modo timelapse/video lento)
  // Nota: La velocidad depende del firmware y la conexión BLE
  await controlChar.write([0x01]); // Intenta 1s o lo que el firmware soporte
}
```

---

## Resumen de Flujo

1.  **Conectar**: Usa `flutter_blue_plus` para encontrar el dispositivo con `omiServiceUuid`.
2.  **Audio In**: Suscríbete a `audioDataStreamUuid` para recibir voz del usuario.
3.  **Audio Out**: Usa el Bluetooth clásico del sistema operativo (emparejamiento normal) para TTS o música.
4.  **Video/Foto**: Suscríbete a `imageDataStreamUuid` para recibir los datos y escribe en `imageControlUuid` para disparar la cámara.