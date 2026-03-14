import 'package:flutter/material.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../memory/domain/repositories/memory_repository.dart';
import '../../../settings/domain/repositories/settings_repository.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository chatRepository;
  final MemoryRepository memoryRepository;
  final SettingsRepository settingsRepository;

  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  ChatViewModel({
    required this.chatRepository,
    required this.memoryRepository,
    required this.settingsRepository,
  });

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Search relevant memories
      final memories = await memoryRepository.search(text, limit: 5);
      
      // 2. Format context
      String context = "";
      if (memories.isNotEmpty) {
        context = "Aquí hay algunos recuerdos relevantes del usuario:\n";
        for (var m in memories) {
          context += "- [${m.timestamp}]: ${m.summary}\n";
          if (m.transcriptOriginal.isNotEmpty) {
            context += "  Transcripción: ${m.transcriptOriginal}\n";
          }
        }
      } else {
        context = "No se encontraron recuerdos específicos relacionados con la pregunta.\n";
      }

      final systemPrompt = """
Eres un asistente personal inteligente para un usuario que usa los OMI Glasses. 
Tu tarea es responder preguntas sobre el pasado y las experiencias del usuario basándote en los recuerdos proporcionados.
Si no encuentras la información en los recuerdos, dilo amablemente.
Responde de forma natural, breve y útil.

$context

Pregunta del usuario: $text
""";

      // 3. Get LLM response
      final settings = await settingsRepository.load();
      String responseText;

      if (settings.useLocalModels && settings.localAudioUrl != null) {
        responseText = await chatRepository.getLocalChatResponse(
          prompt: systemPrompt,
          localUrl: settings.localAudioUrl!,
        );
      } else {
        final apiKey = settings.geminiApiKey ?? '';
        if (apiKey.isEmpty) {
          throw Exception("Gemini API Key es requerida para el chatbot.");
        }
        responseText = await chatRepository.getChatResponse(
          prompt: systemPrompt,
          apiKey: apiKey,
        );
      }

      final assistantMessage = ChatMessage(
        text: responseText,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      _messages.add(assistantMessage);
    } catch (e) {
      _error = e.toString();
      debugPrint("Chat Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages = [];
    _error = null;
    notifyListeners();
  }
}
