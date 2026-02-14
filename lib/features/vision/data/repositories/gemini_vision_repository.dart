import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/vision_repository.dart';

class GeminiVisionRepository implements VisionRepository {
  @override
  Future<String> describeImage({
    required List<int> imageBytes,
    required String apiKey,
    String model = 'gemini-1.5-flash',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );
    final base64Image = base64Encode(imageBytes);
    final body = {
      "contents": [
        {
          "parts": [
            {"text": "Describe the image in Spanish, concise and clear."},
            {
              "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
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
      throw Exception('Gemini error: ${resp.statusCode} ${resp.body}');
    }
    final json = jsonDecode(resp.body);
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return 'Sin descripción';
    }
    final text = candidates[0]['content']?['parts']?[0]?['text'];
    return (text is String && text.isNotEmpty) ? text : 'Sin descripción';
  }
}
