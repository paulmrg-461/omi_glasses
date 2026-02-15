import 'dart:typed_data';

abstract class AudioRepository {
  Future<String> transcribeAndSummarize({
    required Uint8List wavBytes,
    required String apiKey,
    String model,
  });
  Future<List<String>> generateSuggestionsFromText({
    required String text,
    required String apiKey,
    String model,
  });
}

class TranscriptionResult {
  final String transcript;
  final String summary;
  TranscriptionResult({required this.transcript, required this.summary});
}

abstract class AudioRepositoryStructured {
  Future<TranscriptionResult> transcribeAndSummarizeStructured({
    required Uint8List wavBytes,
    required String apiKey,
    String model,
  });
}
