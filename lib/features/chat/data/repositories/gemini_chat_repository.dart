import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omi_glasses/features/chat/domain/repositories/chat_repository.dart';

class GeminiChatRepository implements ChatRepository {
  @override
  Future<String> getChatResponse({
    required String prompt,
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
            {"text": prompt},
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
      throw Exception('Gemini chat error: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return 'No se pudo generar una respuesta.';
    }
    final text = candidates[0]['content']?['parts']?[0]?['text'];
    return (text is String && text.isNotEmpty)
        ? text
        : 'No se pudo generar una respuesta.';
  }

  @override
  Future<String> getLocalChatResponse({
    required String prompt,
    required String localUrl,
  }) async {
    // Assuming a simple completion endpoint for local models
    // Adjust path as needed based on common patterns
    final baseUrl = localUrl.endsWith('/') ? localUrl : '$localUrl/';
    final uri = Uri.parse('${baseUrl}chat/completions');

    final body = {
      "messages": [
        {"role": "user", "content": prompt},
      ],
    };

    final resp = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception('Local chat error: ${resp.statusCode} ${resp.body}');
    }

    final json = jsonDecode(resp.body);
    // Standard OpenAI-like response format
    final choices = json['choices'] as List<dynamic>?;
    if (choices != null && choices.isNotEmpty) {
      return choices[0]['message']?['content'] ?? 'Sin respuesta local';
    }

    // Fallback for other formats
    return json['response'] ?? json['text'] ?? 'Sin respuesta local';
  }
}
