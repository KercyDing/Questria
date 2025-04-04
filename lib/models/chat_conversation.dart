import 'chat_message.dart';

class ChatConversation {
  final int id;
  final String title;
  final List<ChatMessage> messages;

  ChatConversation({
    required this.id,
    required this.title,
    required this.messages,
  });
} 