# Guía: Ejecutar modelos de IA locales en el móvil con Termux

## 1. Objetivo

Esta guía explica cómo ejecutar modelos de IA **locales** en un móvil Android usando **Termux**, aprovechando principalmente la **CPU** y, cuando sea razonable, la **GPU/NNAPI** a través de una app Android de apoyo.

Incluye:
- Requisitos y limitaciones reales en Android.
- Escenario práctico con **Termux + CPU**.
- Escenario con **App Android (GPU/NNAPI) + Termux como cliente**.
- Notas sobre **audio** (speech-to-text, TTS) e **imágenes** (visión, OCR, multimodal).

## 2. Enfoques posibles

### 2.1 Termux + CPU (recomendado para empezar)

- Todo corre dentro de Termux, como si fuera un Linux ligero.
- Se usan modelos cuantizados y librerías optimizadas para CPU (NEON).
- Ventajas:
  - Setup relativamente simple.
  - Control total por terminal (scripts, automatización).
  - Funciona en casi cualquier Android moderno.
- Desventajas:
  - Sin acceso directo a la GPU.
  - Limitado por CPU y RAM del teléfono; modelos deben ser pequeños o muy cuantizados.

### 2.2 App Android + GPU/NNAPI + Termux como cliente

- La **app Android** ejecuta el modelo usando:
  - TensorFlow Lite (GPU/NNAPI),
  - PyTorch Mobile,
  - ncnn + Vulkan,
  - u otras librerías móviles (MLC-LLM, etc.).
- Termux actúa como **cliente** llamando a la app vía HTTP, sockets o Intents.
- Ventajas:
  - Puedes aprovechar GPU/NNAPI y aceleradores dedicados.
  - Mejor rendimiento para modelos medianos.
- Desventajas:
  - Hay que desarrollar y mantener una app Android con esa lógica.

### 2.3 GPU desde Termux (experimental)

- En teoría se puede compilar ncnn/MNN con backend Vulkan y lanzar binarios desde Termux.
- Problemas:
  - No todos los teléfonos exponen correctamente Vulkan/librerías desde el entorno Termux.
  - Requiere toolchains y CMake avanzados.
  - Es frágil ante cambios de sistema o actualizaciones.
- Solo recomendable como experimento, no como solución principal.

## 3. Requisitos generales

- **Teléfono Android** (idealmente Android 10+ con al menos 4 GB de RAM).
- **Termux** instalado desde F-Droid (versión más actual, no la de la Play Store).
- Espacio en disco suficiente:
  - Modelos de texto pequeños: 1–4 GB.
  - Modelos de audio/visión: desde cientos de MB a varios GB.
- Cargador a mano: correr IA local **consume mucha batería**.

## 4. Escenario A – Termux + CPU

### 4.1 Instalación básica de Termux

1. Instalar Termux desde **F-Droid**.
2. Abrir Termux y actualizar paquetes:

   ```bash
   pkg update && pkg upgrade
   ```

3. Habilitar acceso al almacenamiento (opcional, pero útil para modelos grandes):

   ```bash
   termux-setup-storage
   ```

### 4.2 Herramientas base

Instalar conjunto base de herramientas:

```bash
pkg install git clang cmake make openssl python
```

Con esto puedes compilar proyectos C/C++ típicos (como llama.cpp, whisper.cpp, ncnn) y usar Python para scripts ligeros.

### 4.3 Ejemplo 1: LLM pequeño con llama.cpp (solo CPU)

Objetivo: correr un modelo de lenguaje pequeño (1–3B parámetros, cuantizado) íntegramente en Termux.

1. Clonar el repositorio:

   ```bash
   git clone https://github.com/ggerganov/llama.cpp
   cd llama.cpp
   ```

2. Compilar:

   ```bash
   make
   ```

3. Descargar un modelo cuantizado `.gguf` (por ejemplo, un modelo de chat de 1–3B parámetros en Q4/Q5).
   - Copiarlo a una ruta accesible por Termux (por ejemplo `~/models/model.gguf`).

4. Ejecutar:

   ```bash
   ./main \
     -m ~/models/model.gguf \
     -n 256 \
     -p "Hola, ¿quién eres?"
   ```

5. Ajustar parámetros:
   - `-n`: longitud máxima de respuesta.
   - `-t`: número de hilos (usar el número de cores del CPU o uno menos).
   - `-c`: contexto máximo; valores altos consumen más memoria.

Limitantes:
- Cuanto más grande el modelo, más lento y más RAM.
- Para uso interactivo en móvil, suele ser razonable usar modelos **muy cuantizados** y de pocos miles de millones de parámetros.

### 4.4 Ejemplo 2: Audio (speech-to-text) con CPU

Para audio, la idea es usar librerías estilo **whisper.cpp** o runtimes ONNX/TFLite con modelos de voz.

Enfoque típico:

1. Compilar whisper.cpp o similar en Termux (proceso similar a llama.cpp).
2. Tener archivo de audio local (por ejemplo `.wav` o `.mp3` convertido a `.wav`).
3. Ejecutar el binario para transcribirlo:

   ```bash
   ./main -m ~/models/whisper-small.bin -f audio.wav -l es
   ```

Notas:
- Se recomienda usar modelos **small** o **tiny** para móviles.
- Si no quieres compilar, puedes usar Python con librerías ligeras, pero la experiencia suele ser mejor con binarios C++ optimizados.

### 4.5 Ejemplo 3: Visión (imágenes) con CPU

Para imágenes, puedes usar:
- Modelos **ONNX** con runtimes como onnxruntime (versión para ARM).
- Modelos **TFLite** con intérprete de TensorFlow Lite compilado para Android/Termux.

Flujo general:

1. Convertir tu modelo a ONNX/TFLite en tu entorno de desarrollo (PC).
2. Copiar el archivo de modelo al móvil (`~/models/model.onnx` o `model.tflite`).
3. En Termux, ejecutar un script Python que:
   - Cargue la imagen (por ejemplo desde `/sdcard/DCIM`).
   - La preprocese (normalización, resize).
   - Ejecute una inferencia con el runtime CPU.
   - Imprima la predicción.

Limitantes:
- Los modelos de visión grandes pueden ser lentos.
- Es más razonable usar modelos optimizados para móvil (MobileNet, EfficientNet-lite, etc.).

## 5. Escenario B – App Android + GPU/NNAPI + Termux cliente

### 5.1 Arquitectura general

Idea: separar responsabilidades.

- **App Android (“servidor de IA”)**
  - Carga el modelo y lo ejecuta usando GPU/NNAPI/TPU (si existe).
  - Expone una pequeña API local (HTTP, WebSocket, etc.) en `127.0.0.1:<puerto>`.
  - Gestiona audio, cámara y permisos de forma nativa.

- **Termux (“cliente de IA”)**
  - Solo envía peticiones a la app con texto, audio o imágenes.
  - Recibe la respuesta (texto, etiquetas, JSON) y la procesa como quieras (scripts, logs, etc.).

Esto permite:
- Usar aceleración de hardware sin pelear con drivers desde Termux.
- Mantener flexibilidad: cualquier script de Termux puede “usar” la IA llamando al servidor local.

### 5.2 Tecnologías habituales para la app

En la app Android puedes usar:

- **TensorFlow Lite**
  - Soporta delegado GPU y NNAPI.
  - Ideal para visión y audio en modelos optimizados (TFLite).

- **PyTorch Mobile**
  - Para modelos entrenados en PyTorch.
  - Puede usar NNAPI.

- **ncnn + Vulkan**
  - Motor ligero C++ optimizado para móviles.
  - Soporta GPU vía Vulkan.

- **MLC LLM / variantes de llama.cpp para Android**
  - Soluciones ya preparadas para LLMs en móvil con aceleración.

### 5.3 Proceso de alto nivel

1. Elegir modelo:
   - Texto: LLM pequeño/mediano en formato soportado por TF Lite, ncnn, etc.
   - Audio: modelo de STT tipo Whisper convertido a formato móvil.
   - Visión: modelo de clasificación, detección, OCR, o modelo multimodal.

2. Integrarlo en una app Android:
   - Cargar el modelo en `onCreate` o de forma lazy.
   - Exponer una función tipo `runModel(input): output`.

3. Crear una capa de red local en la app:
   - Un servidor HTTP embebido (por ejemplo usando OkHttp/Jetty/Ktor).
   - Endpoints como:
     - `POST /llm` para texto.
     - `POST /stt` para audio.
     - `POST /vision` para imágenes.

4. Desde Termux:
   - Usar `curl` o Python para enviar peticiones:

     ```bash
     curl -X POST http://127.0.0.1:8080/llm \
       -H "Content-Type: application/json" \
       -d '{"prompt": "Describe la escena de esta imagen"}'
     ```

   - Para audio: enviar el archivo o los bytes codificados (por ejemplo base64).
   - Para imágenes: enviar el archivo (multipart/form-data) o su contenido codificado.

5. Recibir la respuesta y usarla en scripts de Termux.

### 5.4 Audio: ¿qué se puede hacer?

Con esta arquitectura, la app Android puede:
- Capturar audio del micrófono.
- Procesarlo con un modelo de **speech-to-text** (STT).
- Opcionalmente usar **text-to-speech** (TTS) local para responder por voz.

Termux puede:
- Enviar comandos o texto, y recibir transcripciones.
- Orquestar lógica avanzada, logs, automatizaciones, etc.

### 5.5 Imágenes: ¿qué se puede hacer?

La app Android puede:
- Acceder directamente a la cámara o a imágenes del almacenamiento.
- Ejecutar:
  - Clasificación de imágenes.
  - Detección de objetos.
  - OCR.
  - Modelos multimodales (texto + imagen) si el hardware lo permite.

Termux puede:
- Pedir predicciones o descripciones (por ejemplo, “describe la foto actual”).
- Integrar esa información con otros servicios locales o remotos.

## 6. Escenario C – GPU desde Termux (ncnn/MNN + Vulkan)

Resumen:

- Requiere compilar librerías de inferencia (ncnn/MNN) con soporte Vulkan.
- Dependencias:
  - Cabeceras y libs de Vulkan de Android.
  - Soporte adecuado en la ROM del teléfono.
- Flujo:
  - Cross-compilar las librerías para ARM/Android.
  - Copiar binarios y librerías a Termux.
  - Ejecutar modelos desde Termux aprovechando Vulkan.

Riesgos:
- No hay garantía de que funcione en todos los dispositivos.
- Puede romperse tras una actualización de sistema.
- La depuración es compleja si algo falla en la capa gráfica/driver.

Recomendación:
- Úsalo solo como experimento si ya tienes experiencia en compilación cruzada y CMake.

## 7. Limitaciones importantes

- **Memoria RAM**
  - Los móviles tienen menos RAM disponible que un PC.
  - Un modelo grande puede provocar OOM o que Android mate el proceso.

- **Almacenamiento**
  - Los modelos ocupan muchos GB; vigila el espacio interno.

- **Batería y temperatura**
  - Inferencias continuas calientan el dispositivo y pueden reducir el rendimiento por thermal throttling.

- **Permisos y seguridad**
  - Acceso a micrófono y cámara pasa por permisos de Android.
  - Evitar exponer servidores accesibles desde la red externa si no es necesario.

- **Tamaño de modelos multimodales**
  - Modelos tipo “todo en uno” (texto + imagen + audio) grandes son difíciles de correr en móvil.
  - La estrategia práctica suele ser usar varios modelos más pequeños (uno para texto, otro para audio, otro para visión).

## 8. ¿Puedo usar modelos que interpreten audio e imágenes?

Sí, pero con restricciones y arquitectura adecuada:

- **Solo Termux + CPU**
  - Audio: modelos tipo Whisper pequeños/medianos, pero con latencia mayor.
  - Visión: modelos ligeros optimizados para móvil (MobileNet, EfficientNet-lite, etc.).
  - Multimodal complejo: limitado; mejor separar tareas (audio → texto, imagen → etiquetas) y fusionar lógicamente en scripts.

- **App Android + aceleración**
  - Audio:
    - STT local (Whisper convertido a formato móvil o modelos específicos).
    - TTS local para respuestas.
  - Imágenes:
    - Clasificación, detección, OCR, etc., usando GPU/NNAPI.
  - Multimodal:
    - Modelos compactos que combinen texto + imagen, si tu hardware lo soporta.

En ambos casos, Termux puede orquestar:
- Captura (vía app o herramientas del sistema).
- Envío de datos a la app o binarios locales.
- Recepción de resultados y lógica posterior (automatizaciones, resúmenes, etc.).

## 9. Checklist rápida

1. Instalar Termux desde F-Droid.
2. Configurar entorno base (`pkg update`, herramientas de compilación, Python).
3. Elegir enfoque:
   - Solo CPU en Termux (más simple).
   - App Android + GPU/NNAPI + Termux cliente (más potente).
4. Empezar por un modelo pequeño (texto o audio) y validar:
   - Latencia aceptable.
   - Consumo de batería razonable.
5. Añadir visión/imágenes una vez validado lo anterior.
6. Si necesitas aún más rendimiento, evaluar app Android con aceleración y exponer API local hacia Termux.

