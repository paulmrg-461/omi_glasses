abstract class ChatRepository {
  Future<String> getChatResponse({
    required String prompt,
    required String apiKey,
    String model = 'gemini-2.5-flash',
  });

  Future<String> getLocalChatResponse({
    required String prompt,
    required String localUrl,
  });
}
