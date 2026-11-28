import 'dart:async';

import 'package:what2eat_starter/features/messaging/messaging_models.dart';
import 'package:what2eat_starter/features/messaging/messaging_repository.dart';

const chatCustomer = '11111111-1111-4111-8111-111111111111';
const chatVendorUser = '22222222-2222-4222-8222-222222222222';
const chatVendor = '33333333-3333-4333-8333-333333333333';
const chatThread = '44444444-4444-4444-8444-444444444444';

class FakeMessagingRepository implements MessagingRepository {
  FakeMessagingRepository({this.role = ChatRole.customer, this.canSend = true});
  final ChatRole role;
  bool canSend;
  bool failNextSend = false;
  bool failIdentity = false;
  bool emptyInbox = false;
  int readCalls = 0, startCalls = 0, olderCalls = 0;
  final sendIds = <String>[];
  final stored = <ChatMessage>[];
  final events = StreamController<void>.broadcast();
  String get userId =>
      role == ChatRole.customer ? chatCustomer : chatVendorUser;

  ChatConversation get thread => ChatConversation(
    id: chatThread,
    customerId: chatCustomer,
    vendorId: chatVendor,
    name: role == ChatRole.customer ? 'Mama Siti Kitchen' : 'Ali',
    updatedAt: stored.isEmpty
        ? DateTime(2026, 11, 26, 12)
        : stored.last.createdAt,
    canSend: canSend,
    lastMessage: stored.isEmpty ? null : stored.last,
  );

  @override
  Future<ChatIdentity> identity() async {
    if (failIdentity) throw const ChatFailure('Sign in again to use messages.');
    return ChatIdentity(
      userId: userId,
      role: role,
      vendorId: role == ChatRole.vendor ? chatVendor : null,
    );
  }

  @override
  Future<List<ChatConversation>> conversations({
    ChatConversation? before,
  }) async => emptyInbox ? [] : [thread];
  @override
  Future<ChatConversation> startConversation(String vendorId) async {
    startCalls++;
    emptyInbox = false;
    return thread;
  }

  @override
  Future<ChatConversation> conversation(String id) async => thread;
  @override
  Future<List<ChatMessage>> messages(
    String conversationId, {
    ChatMessage? before,
  }) async {
    if (before != null) olderCalls++;
    final rows =
        stored
            .where(
              (message) =>
                  before == null ||
                  message.createdAt.isBefore(before.createdAt) ||
                  (message.createdAt == before.createdAt &&
                      message.id.compareTo(before.id) < 0),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows.take(SupabaseMessagingRepository.pageSize).toList();
  }

  @override
  Future<ChatMessage> send(
    String conversationId,
    String text, {
    required String clientId,
  }) async {
    sendIds.add(clientId);
    if (failNextSend) {
      failNextSend = false;
      throw const ChatFailure('Test connection lost. Try again.');
    }
    final existing = stored.where((message) => message.id == clientId);
    if (existing.isNotEmpty) return existing.first;
    final message = ChatMessage(
      id: clientId,
      conversationId: conversationId,
      senderId: userId,
      content: text,
      createdAt: DateTime.now(),
    );
    stored.add(message);
    return message;
  }

  @override
  Future<void> markRead(String conversationId) async {
    readCalls++;
    for (var i = 0; i < stored.length; i++) {
      final old = stored[i];
      if (old.senderId == userId || old.isRead) continue;
      stored[i] = ChatMessage(
        id: old.id,
        conversationId: old.conversationId,
        senderId: old.senderId,
        content: old.content,
        createdAt: old.createdAt,
        isRead: true,
      );
    }
  }

  @override
  Stream<void> changes({String? conversationId}) => events.stream;
  void incoming(String text) {
    stored.add(
      ChatMessage(
        id: newChatMessageId(),
        conversationId: chatThread,
        senderId: role == ChatRole.customer ? chatVendorUser : chatCustomer,
        content: text,
        createdAt: DateTime.now(),
      ),
    );
    events.add(null);
  }

  Future<void> dispose() => events.close();
}
