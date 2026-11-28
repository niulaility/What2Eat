import 'dart:math';

enum ChatRole { customer, vendor }

class ChatIdentity {
  const ChatIdentity({required this.userId, required this.role, this.vendorId});
  final String userId;
  final ChatRole role;
  final String? vendorId;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });
  final String id, conversationId, senderId, content;
  final DateTime createdAt;
  final bool isRead;

  factory ChatMessage.fromJson(Map<String, dynamic> row) => ChatMessage(
    id: row['id'] as String,
    conversationId: row['conversation_id'] as String,
    senderId: row['sender_id'] as String,
    content: row['content'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    isRead: row['is_read'] == true,
  );
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.name,
    required this.updatedAt,
    required this.canSend,
    this.lastMessage,
  });
  final String id, customerId, vendorId, name;
  final DateTime updatedAt;
  final bool canSend;
  final ChatMessage? lastMessage;
  bool hasUnread(String userId) =>
      lastMessage != null &&
      lastMessage!.senderId != userId &&
      !lastMessage!.isRead;
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

const maxChatMessageLength = 2000;

bool isChatEntityId(String id) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(id);

String? validateChatMessage(String text) {
  if (text.trim().isEmpty) return 'Write a message first.';
  if (text.trim().length > maxChatMessageLength) {
    return 'Keep messages within $maxChatMessageLength characters.';
  }
  return null;
}

String newChatMessageId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String chatFailureText(Object error) => error is ChatFailure
    ? error.message
    : 'Could not connect. Check your connection and try again.';
