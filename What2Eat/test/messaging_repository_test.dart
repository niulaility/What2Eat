import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:what2eat_starter/features/messaging/messaging_models.dart';
import 'package:what2eat_starter/features/messaging/messaging_repository.dart';

import 'support/messaging_fixture.dart';

Map<String, dynamic> messageRow(
  String id, {
  String sender = chatCustomer,
  String content = 'Hello',
}) => {
  'id': id,
  'conversation_id': chatThread,
  'sender_id': sender,
  'content': content,
  'created_at': '2026-11-26T12:00:00Z',
  'is_read': false,
};

Map<String, dynamic> threadRow({
  String customerId = chatCustomer,
  bool active = true,
}) => {
  'id': chatThread,
  'customer_id': customerId,
  'vendor_id': chatVendor,
  'last_message_at': '2026-11-26T12:00:00Z',
  'vendor': {
    'id': chatVendor,
    'user_id': chatVendorUser,
    'business_name': 'Mama Siti Kitchen',
    'status': 'approved',
    'is_active': active,
  },
  'customer': {
    'id': customerId,
    'full_name': 'Ali',
    'username': 'ali',
    'is_active': true,
  },
  'messages': [
    messageRow('55555555-5555-4555-8555-555555555555', sender: chatVendorUser),
  ],
};

http.Response jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
Object singleOrList(http.Request request, Map<String, dynamic> row) =>
    request.headers['accept']?.contains('vnd.pgrst.object') == true
    ? row
    : [row];

Future<SupabaseClient> testClient(
  Future<http.Response> Function(http.Request) handler, {
  ChatRole role = ChatRole.customer,
  bool signedIn = true,
}) async {
  final client = SupabaseClient(
    'https://chat-test.invalid',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      final response = await handler(request);
      return http.Response.bytes(
        response.bodyBytes,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  if (signedIn) {
    final id = role == ChatRole.customer ? chatCustomer : chatVendorUser;
    final expiry =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token':
            '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': id, 'exp': expiry, 'role': 'authenticated'})}.test',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_at': expiry,
        'user': {
          'id': id,
          'aud': 'authenticated',
          'email': 'fake@example.invalid',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
  }
  addTearDown(client.dispose);
  return client;
}

http.Response? identityResponse(
  http.Request request, {
  ChatRole role = ChatRole.customer,
  bool active = true,
}) {
  if (request.url.path.endsWith('/profiles')) {
    return jsonResponse({
      'id': role == ChatRole.customer ? chatCustomer : chatVendorUser,
      'role': role == ChatRole.customer ? 'student' : 'vendor',
      'is_active': active,
    });
  }
  if (request.url.path.endsWith('/vendors')) {
    return jsonResponse(
      singleOrList(request, {
        'id': chatVendor,
        'user_id': chatVendorUser,
        'status': 'approved',
        'is_active': active,
      }),
    );
  }
  return null;
}

void main() {
  test(
    'Empty/oversized messages fail validation and IDs are distinct UUIDs',
    () {
      expect(validateChatMessage(' \n '), isNotNull);
      expect(validateChatMessage('a' * 2001), isNotNull);
      expect(validateChatMessage('Hello vendor'), isNull);
      final ids = List.generate(100, (_) => newChatMessageId());
      expect(ids.toSet().length, 100);
      expect(ids, everyElement(matches(RegExp(r'^[0-9a-f-]{36}$'))));
    },
  );

  test('Unauthenticated users cannot issue message requests', () async {
    var calls = 0;
    final client = await testClient((request) async {
      calls++;
      return jsonResponse([]);
    }, signedIn: false);
    await expectLater(
      SupabaseMessagingRepository(client).conversations(),
      throwsA(isA<ChatFailure>()),
    );
    expect(calls, 0);
  });

  for (final role in ChatRole.values) {
    test('$role inbox is explicitly scoped to its participant ID', () async {
      final client = await testClient((request) async {
        final identity = identityResponse(request, role: role);
        if (identity != null) return identity;
        expect(
          request.url.queryParameters[role == ChatRole.customer
              ? 'customer_id'
              : 'vendor_id'],
          'eq.${role == ChatRole.customer ? chatCustomer : chatVendor}',
        );
        expect(request.url.queryParameters['messages.limit'], '1');
        return jsonResponse([threadRow()]);
      }, role: role);
      final rows = await SupabaseMessagingRepository(client).conversations();
      expect(
        rows.single.name,
        role == ChatRole.customer ? 'Mama Siti Kitchen' : 'Ali',
      );
    });
  }

  test(
    'Forged conversation data does not bypass client participant checks',
    () async {
      final client = await testClient(
        (request) async =>
            identityResponse(request) ??
            jsonResponse([
              threadRow(customerId: '66666666-6666-4666-8666-666666666666'),
            ]),
      );
      await expectLater(
        SupabaseMessagingRepository(client).conversations(),
        throwsA(isA<ChatFailure>()),
      );
    },
  );

  test('Suspended accounts are rejected before conversation reads', () async {
    final client = await testClient(
      (request) async => identityResponse(request, active: false)!,
    );
    await expectLater(
      SupabaseMessagingRepository(client).conversations(),
      throwsA(isA<ChatFailure>()),
    );
  });

  test(
    'Send uses authenticated sender and a stable ID; retry deduplicates',
    () async {
      Map<String, dynamic>? stored;
      final id = newChatMessageId();
      final client = await testClient((request) async {
        final identity = identityResponse(request);
        if (identity != null) return identity;
        if (request.url.path.endsWith('/conversations')) {
          return jsonResponse(singleOrList(request, threadRow()));
        }
        if (request.method == 'POST') {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['sender_id'], chatCustomer);
          expect(payload['content'], 'Hello');
          expect(payload['id'], id);
          if (stored != null) {
            return jsonResponse({
              'code': '23505',
              'message': 'duplicate',
            }, status: 409);
          }
          stored = messageRow(id);
          return jsonResponse(stored, status: 201);
        }
        expect(request.url.queryParameters['id'], 'eq.$id');
        expect(request.url.queryParameters['sender_id'], 'eq.$chatCustomer');
        return jsonResponse(stored);
      });
      final repo = SupabaseMessagingRepository(client);
      final first = await repo.send(chatThread, ' Hello ', clientId: id);
      final retry = await repo.send(chatThread, 'Hello', clientId: id);
      expect(first.id, retry.id);
    },
  );

  test(
    'Read updates only touch unread incoming messages in this conversation',
    () async {
      var updated = false;
      final client = await testClient((request) async {
        final identity = identityResponse(request);
        if (identity != null) return identity;
        if (request.url.path.endsWith('/conversations')) {
          return jsonResponse(singleOrList(request, threadRow()));
        }
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {'is_read': true});
        expect(
          request.url.queryParameters['conversation_id'],
          'eq.$chatThread',
        );
        expect(request.url.queryParameters['sender_id'], 'neq.$chatCustomer');
        expect(request.url.queryParameters['is_read'], 'eq.false');
        updated = true;
        return http.Response('', 204);
      });
      await SupabaseMessagingRepository(client).markRead(chatThread);
      expect(updated, isTrue);
    },
  );

  test(
    'Message history uses a timestamp and ID cursor for equal-time messages',
    () async {
      final id = newChatMessageId();
      http.Request? historyRequest;
      final client = await testClient((request) async {
        final identity = identityResponse(request);
        if (identity != null) return identity;
        if (request.url.path.endsWith('/conversations')) {
          return jsonResponse(singleOrList(request, threadRow()));
        }
        historyRequest = request;
        return jsonResponse([]);
      });
      await SupabaseMessagingRepository(client)
          .messages(chatThread, before: ChatMessage.fromJson(messageRow(id)));
      expect(historyRequest!.url.queryParameters['or'], contains('id.lt.$id'));
      expect(
        historyRequest!.url.queryParameters['order'],
        allOf(startsWith('created_at.desc'), contains(',id.desc')),
      );
      expect(historyRequest!.url.queryParameters['limit'], '40');
    },
  );

  test(
    'Starting a thread reuses the existing customer/vendor conversation',
    () async {
      var inserted = false;
      final client = await testClient((request) async {
        final identity = identityResponse(request);
        if (identity != null) return identity;
        if (request.method == 'POST') inserted = true;
        return jsonResponse(
          singleOrList(
            request,
            request.url.queryParameters['select'] == 'id'
                ? {'id': chatThread}
                : threadRow(),
          ),
        );
      });
      final thread = await SupabaseMessagingRepository(client)
          .startConversation(chatVendor);
      expect(thread.id, chatThread);
      expect(inserted, isFalse);
    },
  );
}
