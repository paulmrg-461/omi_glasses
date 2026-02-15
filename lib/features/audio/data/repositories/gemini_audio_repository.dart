import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/repositories/audio_repository.dart';

class GeminiAudioRepository implements AudioRepository {
  @override
  Future<String> transcribeAndSummarize({
    required Uint8List wavBytes,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
                  "Transcribe el audio en español y luego genera un resumen breve y claro de la conversación.",
            },
            {
              "inline_data": {
                "mime_type": "audio/wav",
                "data": base64Encode(wavBytes),
              },
            },
          ],
        },
      ],
    };
    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      throw Exception('Gemini audio error: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return 'Sin resumen';
    }
    final text = candidates[0]['content']?['parts']?[0]?['text'];
    return (text is String && text.isNotEmpty) ? text : 'Sin resumen';
  }

  @override
  Future<List<String>> generateSuggestionsFromText({
    required String text,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
                  "A partir del siguiente resumen/transcripción, devuelve una lista de sugerencias de acciones en formato JSON con la clave 'suggestions' como arreglo de strings. Texto:\n$text",
            },
          ],
        },
      ],
    };
    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      // Fall back to simple parsing: bullet lines
      return [];
    }
    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return [];
    }
    final outText = candidates[0]['content']?['parts']?[0]?['text'];
    if (outText is String) {
      try {
        final obj = jsonDecode(outText);
        final list = (obj['suggestions'] as List)
            .map((e) => e.toString())
            .toList();
        return list;
      } catch (_) {
        // If not valid JSON, split lines
        return outText
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
      }
    }
    return [];
  }
}

class GeminiAudioRepositoryStructured implements AudioRepositoryStructured {
  String _sanitizeJsonText(String text) {
    var s = text.trim();
    if (s.startsWith('```')) {
      final end = s.lastIndexOf('```');
      if (end > 0) {
        s = s.substring(3, end).trim();
        if (s.toLowerCase().startsWith('json')) {
          s = s.substring(4).trim();
        }
      }
    }
    final startBrace = s.indexOf('{');
    final endBrace = s.lastIndexOf('}');
    if (startBrace >= 0 && endBrace >= startBrace) {
      s = s.substring(startBrace, endBrace + 1);
    }
    return s;
  }

  @override
  Future<TranscriptionResult> transcribeAndSummarizeStructured({
    required Uint8List wavBytes,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final body = {
      "contents": [
        {
          "parts": [
            {
              "text":
                  "Transcribe el audio en español y genera un resumen breve y claro. Devuelve estrictamente un JSON con las claves 'transcript' y 'summary'.",
            },
            {
              "inline_data": {
                "mime_type": "audio/wav",
                "data": base64Encode(wavBytes),
              },
            },
          ],
        },
      ],
    };
    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (resp.statusCode != 200) {
      return TranscriptionResult(transcript: '', summary: '');
    }
    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return TranscriptionResult(transcript: '', summary: '');
    }
    final text = candidates[0]['content']?['parts']?[0]?['text'];
    if (text is String) {
      try {
        final cleaned = _sanitizeJsonText(text);
        final obj = jsonDecode(cleaned);
        final t = obj['transcript']?.toString() ?? '';
        final s = obj['summary']?.toString() ?? '';
        return TranscriptionResult(transcript: t, summary: s);
      } catch (_) {
        return TranscriptionResult(transcript: text, summary: text);
      }
    }
    return TranscriptionResult(transcript: '', summary: '');
  }
}
