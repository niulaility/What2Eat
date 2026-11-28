import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'messaging_models.dart';

abstract class MessagingRepository {
  Future<ChatIdentity> identity();
  Future<List<ChatConversation>> conversations({ChatConversation? before});
  Future<ChatConversation> startConversation(String vendorId);
  Future<ChatConversation> conversation(String id);
  Future<List<ChatMessage>> messages(
    String conversationId, {
    ChatMessage? before,
  });
  Future<ChatMessage> send(
    String conversationId,
    String text, {
    required String clientId,
  });
  Future<void> markRead(String conversationId);
  Stream<void> changes({String? conversationId});
}

class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository(this.client);
  final SupabaseClient client;
  static const pageSize = 40;
  static const _columns =
      'id,customer_id,vendor_id,last_message_at,'
      'vendor:vendors!conversations_vendor_id_fkey(id,user_id,business_name,status,is_active),'
      'customer:profiles!conversations_customer_id_fkey(id,full_name,username,is_active)';

  String get _userId =>
      client.auth.currentUser?.id ??
      (throw const ChatFailure(
        'Your session has expired. Sign in again to use messages.',
      ));

  void _validId(String id) {
    if (!isChatEntityId(id)) {
      throw const ChatFailure(
        'Messaging is available for registered vendors and conversations only.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      final startedUser = _userId;
      final result = await action().timeout(const Duration(seconds: 20));
      if (_userId != startedUser) {
        throw const ChatFailure('Your account has changed. Reopen messages.');
      }
      return result;
    } on ChatFailure {
      rethrow;
    } on AuthException {
      throw const ChatFailure('Your session has expired. Sign in again.');
    } on PostgrestException catch (error) {
      if (['42P01', 'PGRST200', 'PGRST205', '42703'].contains(error.code)) {
        throw const ChatFailure(
          'Messaging is not configured on the server yet. Please contact the administrator.',
        );
      }
      if (['42501', 'PGRST301', 'PGRST302', 'PGRST303'].contains(error.code)) {
        throw const ChatFailure(
          'This conversation is unavailable or your session has expired.',
        );
      }
      throw const ChatFailure(
        'Could not complete that message request. Please try again.',
      );
    } on Exception {
      throw const ChatFailure(
        'Could not connect. Check your connection and try again.',
      );
    }
  }

  @override
  Future<ChatIdentity> identity() => _guard(() async {
    final userId = _userId;
    final profile = await client
        .from('profiles')
        .select('id,role,is_active')
        .eq('id', userId)
        .single();
    if (_userId != userId) {
      throw const ChatFailure('Your account has changed. Reopen messages.');
    }
    if (profile['is_active'] == false) {
      throw const ChatFailure('Messaging is unavailable for this account.');
    }
    if (profile['role'] == 'student') {
      return ChatIdentity(userId: userId, role: ChatRole.customer);
    }
    if (profile['role'] != 'vendor') {
      throw const ChatFailure(
        'Messaging is available to customers and vendors.',
      );
    }
    final vendor = await client
        .from('vendors')
        .select('id,status,is_active')
        .eq('user_id', userId)
        .maybeSingle();
    if (vendor == null ||
        vendor['status'] != 'approved' ||
        vendor['is_active'] != true) {
      throw const ChatFailure(
        'Messaging requires an approved, active vendor account.',
      );
    }
    return ChatIdentity(
      userId: userId,
      role: ChatRole.vendor,
      vendorId: vendor['id'] as String,
    );
  });

  ChatConversation _fromRow(Map<String, dynamic> row, ChatIdentity user) {
    final customerId = row['customer_id'] as String;
    final vendorId = row['vendor_id'] as String;
    if (user.role == ChatRole.customer
        ? customerId != user.userId
        : vendorId != user.vendorId) {
      throw const ChatFailure('You do not have access to this conversation.');
    }
    final vendor = row['vendor'] as Map<String, dynamic>?;
    final customer = row['customer'] as Map<String, dynamic>?;
    final fullName = (customer?['full_name'] as String?)?.trim();
    final name = user.role == ChatRole.customer
        ? (vendor?['business_name'] as String? ?? 'Vendor')
        : (fullName?.isNotEmpty == true
              ? fullName!
              : customer?['username'] as String? ?? 'Customer');
    final recent = row['messages'] as List<dynamic>? ?? [];
    return ChatConversation(
      id: row['id'] as String,
      customerId: customerId,
      vendorId: vendorId,
      name: name,
      updatedAt: DateTime.parse(row['last_message_at'] as String).toLocal(),
      canSend:
          vendor?['status'] == 'approved' &&
          vendor?['is_active'] == true &&
          customer?['is_active'] != false,
      lastMessage: recent.isEmpty
          ? null
          : ChatMessage.fromJson(Map<String, dynamic>.from(recent.first)),
    );
  }

  @override
  Future<List<ChatConversation>> conversations({
    ChatConversation? before,
  }) => _guard(() async {
    final user = await identity();
    var query = client
        .from('conversations')
        .select(
          '$_columns,messages(id,conversation_id,sender_id,content,is_read,created_at)',
        )
        .eq(
          user.role == ChatRole.customer ? 'customer_id' : 'vendor_id',
          user.role == ChatRole.customer ? user.userId : user.vendorId!,
        );
    if (before != null) {
      _validId(before.id);
      final date = before.updatedAt.toUtc().toIso8601String();
      query = query.or(
        'last_message_at.lt.$date,and(last_message_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('last_message_at', ascending: false)
        .order('id', ascending: false)
        .order('created_at', referencedTable: 'messages', ascending: false)
        .limit(1, referencedTable: 'messages')
        .limit(pageSize);
    if (_userId != user.userId) {
      throw const ChatFailure('Your account has changed. Reopen messages.');
    }
    return rows.map((row) => _fromRow(row, user)).toList();
  });

  @override
  Future<ChatConversation> conversation(String id) => _guard(() async {
    _validId(id);
    final user = await identity();
    final row = await client
        .from('conversations')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw const ChatFailure('This conversation is no longer available.');
    }
    if (_userId != user.userId) {
      throw const ChatFailure('Your account has changed. Reopen messages.');
    }
    return _fromRow(row, user);
  });

  @override
  Future<ChatConversation> startConversation(String vendorId) =>
      _guard(() async {
        _validId(vendorId);
        final user = await identity();
        if (user.role != ChatRole.customer) {
          throw const ChatFailure(
            'Customers can start a conversation from a vendor page.',
          );
        }
        final vendor = await client
            .from('vendors')
            .select('id,user_id,status,is_active')
            .eq('id', vendorId)
            .maybeSingle();
        if (vendor == null ||
            vendor['status'] != 'approved' ||
            vendor['is_active'] != true ||
            vendor['user_id'] == user.userId) {
          throw const ChatFailure('This vendor is not available for messages.');
        }
        final existing = await client
            .from('conversations')
            .select('id')
            .eq('customer_id', user.userId)
            .eq('vendor_id', vendorId)
            .maybeSingle();
        if (existing != null) return conversation(existing['id'] as String);
        if (_userId != user.userId) {
          throw const ChatFailure('Your account has changed. Reopen messages.');
        }
        try {
          final created = await client
              .from('conversations')
              .insert({'customer_id': user.userId, 'vendor_id': vendorId})
              .select('id')
              .single();
          return await conversation(created['id'] as String);
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          final winner = await client
              .from('conversations')
              .select('id')
              .eq('customer_id', user.userId)
              .eq('vendor_id', vendorId)
              .single();
          return conversation(winner['id'] as String);
        }
      });

  @override
  Future<List<ChatMessage>> messages(
    String conversationId, {
    ChatMessage? before,
  }) => _guard(() async {
    await conversation(conversationId);
    var query = client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);
    if (before != null) {
      _validId(before.id);
      if (before.conversationId != conversationId) {
        throw const ChatFailure('Invalid message history position.');
      }
      final date = before.createdAt.toUtc().toIso8601String();
      query = query.or(
        'created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id})',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(pageSize);
    return rows.map(ChatMessage.fromJson).toList();
  });

  @override
  Future<ChatMessage> send(
    String conversationId,
    String text, {
    required String clientId,
  }) => _guard(() async {
    final validation = validateChatMessage(text);
    if (validation != null) throw ChatFailure(validation);
    _validId(clientId);
    final userId = _userId;
    final thread = await conversation(conversationId);
    if (!thread.canSend) {
      throw const ChatFailure(
        'This vendor or customer is not currently available for messages.',
      );
    }
    if (_userId != userId) {
      throw const ChatFailure('Your account has changed. Reopen messages.');
    }
    try {
      final row = await client
          .from('messages')
          .insert({
            'id': clientId,
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': text.trim(),
          })
          .select()
          .single();
      return ChatMessage.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final row = await client
          .from('messages')
          .select()
          .eq('id', clientId)
          .eq('conversation_id', conversationId)
          .eq('sender_id', userId)
          .single();
      if (row['content'] != text.trim()) {
        throw const ChatFailure(
          'This message was already sent with different text.',
        );
      }
      return ChatMessage.fromJson(row);
    }
  });

  @override
  Future<void> markRead(String conversationId) => _guard(() async {
    await conversation(conversationId);
    await client
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', _userId)
        .eq('is_read', false);
  });

  @override
  Stream<void> changes({String? conversationId}) {
    RealtimeChannel? channel;
    var cancelled = false;
    late final StreamController<void> controller;
    controller = StreamController<void>(
      onListen: () async {
        try {
          final user = await identity();
          if (cancelled) return;
          if (conversationId != null) await conversation(conversationId);
          if (cancelled) return;
          channel = client
              .channel('chat-${newChatMessageId()}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: conversationId == null ? 'conversations' : 'messages',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: conversationId != null
                      ? 'conversation_id'
                      : user.role == ChatRole.customer
                      ? 'customer_id'
                      : 'vendor_id',
                  value:
                      conversationId ??
                      (user.role == ChatRole.customer
                          ? user.userId
                          : user.vendorId!),
                ),
                callback: (_) {
                  if (!cancelled) controller.add(null);
                },
              )
              .subscribe((status, error) {
                if (cancelled) return;
                if (status == RealtimeSubscribeStatus.subscribed) {
                  controller.add(null);
                }
                if (status == RealtimeSubscribeStatus.channelError ||
                    status == RealtimeSubscribeStatus.timedOut) {
                  controller.addError(
                    const ChatFailure(
                      'Live updates disconnected. Messages will refresh automatically.',
                    ),
                  );
                }
              });
        } catch (error) {
          if (!cancelled) controller.addError(error);
        }
      },
      onCancel: () async {
        cancelled = true;
        if (channel != null) await client.removeChannel(channel!);
      },
    );
    return controller.stream;
  }
}
