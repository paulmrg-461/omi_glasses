import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/repositories/audio_repository.dart';

class GeminiAudioRepository implements AudioRepository {
  @override
  Future<String> transcribeAndSummarize({
    required Uint8List wavBytes,
    required String apiKey,
    String model = 'gemini-1.5-flash',
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
                  "Transcribe el audio en español y luego genera un resumen breve y claro de la conversación."
            },
            {
              "inline_data": {
                "mime_type": "audio/wav",
                "data": base64Encode(wavBytes),
              }
            }
          ]
        }
      ]
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
}
