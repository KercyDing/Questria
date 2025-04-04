import 'file_attachment.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<FileAttachment>? attachments;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.attachments,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? text,
    bool? preserveAttachments,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isUser: isUser,
      timestamp: timestamp,
      attachments: attachments,
    );
  }
} 