import 'package:equatable/equatable.dart';

enum MessageRole { user, assistant }

class ChatMessage extends Equatable {
  final String text;
  final MessageRole role;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [text, role, timestamp];
}
