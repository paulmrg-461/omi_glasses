import 'dart:typed_data';

abstract class AudioRepository {
  Future<String> transcribeAndSummarize({
    required Uint8List wavBytes,
    required String apiKey,
    String model,
  });
}
