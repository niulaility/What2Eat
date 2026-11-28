import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/messaging/messaging_models.dart';
import 'package:what2eat_starter/features/messaging/messaging_pages.dart';
import 'package:what2eat_starter/features/student/customer_dashboard_page.dart';
import 'package:what2eat_starter/features/student/models/customer_discovery_models.dart';
import 'package:what2eat_starter/features/student/vendor_profile_page.dart';
import 'package:what2eat_starter/features/vendor/vendor_dashboard_page.dart';

import 'support/messaging_fixture.dart';

Future<void> openChat(
  WidgetTester tester,
  FakeMessagingRepository repo, {
  double width = 411,
  double height = 891,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: ConversationPage(conversation: repo.thread, repository: repo),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeMessagingRepository repo;
  setUp(() => repo = FakeMessagingRepository());
  tearDown(() => repo.dispose());

  testWidgets(
    'Customer opens inbox, reads the vendor reply and sends a message',
    (tester) async {
      repo.incoming('Pickup is at 12:30.');
      await tester.pumpWidget(
        MaterialApp(home: MessagesPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mama Siti Kitchen'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('conversation-$chatThread')));
      await tester.pumpAndSettle();
      expect(repo.readCalls, greaterThan(0));
      await tester.enterText(
        find.byKey(const ValueKey('message-composer')),
        'Thank you!',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send-message')));
      await tester.pumpAndSettle();
      expect(repo.stored.last.senderId, chatCustomer);
      expect(repo.stored.last.content, 'Thank you!');
      expect(
        find.byKey(ValueKey('chat-message-${repo.stored.last.id}')),
        findsOneWidget,
      );
    },
  );

  testWidgets('Failed messages retain their text and retry with the same ID', (
    tester,
  ) async {
    repo.failNextSend = true;
    await openChat(tester, repo);
    final send = find.byKey(const ValueKey('send-message'));
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('message-composer')),
      'Is lunch still available?',
    );
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(repo.stored, isEmpty);
    final id = repo.sendIds.single;
    final retry = find.byKey(ValueKey('retry-message-$id'));
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(repo.sendIds, [id, id]);
    expect(repo.stored.single.content, 'Is lunch still available?');
    repo.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('chat-message-$id')), findsOneWidget);
    expect(find.byKey(ValueKey('retry-message-$id')), findsNothing);
  });

  testWidgets(
    'Incoming live messages appear without discarding a typed draft',
    (tester) async {
      await openChat(tester, repo);
      final composer = find.byKey(const ValueKey('message-composer'));
      await tester.enterText(composer, 'My unsent question');
      repo.incoming('Yes, we can help.');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(composer).controller!.text,
        'My unsent question',
      );
      expect(
        find.byKey(ValueKey('chat-message-${repo.stored.last.id}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Older history loads separately and preserves the newest messages',
    (tester) async {
      for (var index = 0; index < 41; index++) {
        repo.stored.add(
          ChatMessage(
            id: newChatMessageId(),
            conversationId: chatThread,
            senderId: chatVendorUser,
            content: 'History $index',
            createdAt: DateTime(2026, 11, 26, 12, index),
          ),
        );
      }
      await openChat(tester, repo);
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('chat-history')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('load-older-messages')));
      await tester.pumpAndSettle();
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(repo.olderCalls, 1);
      expect(
        find.byKey(ValueKey('chat-message-${repo.stored.first.id}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Unavailable conversations keep history visible but disable sending',
    (tester) async {
      repo.canSend = false;
      repo.incoming('Previous message');
      await openChat(tester, repo);
      expect(find.byKey(const ValueKey('message-composer')), findsNothing);
      expect(find.byKey(const ValueKey('send-message')), findsNothing);
      expect(find.textContaining('read-only'), findsOneWidget);
    },
  );

  testWidgets('Sign-in errors are recoverable and empty inbox is explicit', (
    tester,
  ) async {
    repo.failIdentity = true;
    repo.emptyInbox = true;
    await tester.pumpWidget(MaterialApp(home: MessagesPage(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Sign in again to use messages.'), findsOneWidget);
    repo.failIdentity = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('Vendor inbox shows the customer and sends as the vendor', (
    tester,
  ) async {
    final vendor = FakeMessagingRepository(role: ChatRole.vendor);
    addTearDown(vendor.dispose);
    vendor.incoming('Where can I collect my order?');
    await tester.pumpWidget(
      MaterialApp(home: MessagesPage(repository: vendor)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ali'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('conversation-$chatThread')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('message-composer')),
      'At the main gate.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();
    expect(vendor.stored.last.senderId, chatVendorUser);
  });

  testWidgets('Customer and vendor dashboard messaging entries are enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerDashboardPage(name: 'Ali', messagingRepository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('customer-tab-Messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        home: VendorDashboardPage(name: 'Siti', messagingRepository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vendor-tab-Messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesPage), findsOneWidget);
  });

  testWidgets('Message vendor starts the thread from the vendor profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VendorProfilePage(
          vendor: const VendorProfile(
            id: chatVendor,
            businessName: 'Mama Siti Kitchen',
            businessDescription: 'Fresh meals for students',
            businessContactNumber: '0123456789',
            businessAddress: 'Campus',
            universityIds: [],
            offeredSessions: [],
            availableDatesBySession: {},
            menuItems: [],
          ),
          universities: const [],
          messagingRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('message-vendor'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repo.startCalls, 1);
    expect(find.byKey(const ValueKey('message-composer')), findsOneWidget);
  });

  for (final size in [
    (320.0, 812.0, 1.0),
    (375.0, 812.0, 2.0),
    (812.0, 375.0, 1.5),
  ]) {
    testWidgets(
      'Messaging fits ${size.$1}x${size.$2} with ${size.$3} text scale',
      (tester) async {
        repo.incoming('Hello! How can we help with your order today?');
        await openChat(
          tester,
          repo,
          width: size.$1,
          height: size.$2,
          scale: size.$3,
        );
        await tester.enterText(
          find.byKey(const ValueKey('message-composer')),
          'Thank you for your help.',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$3)),
              child: child!,
            ),
            home: MessagesPage(repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Composer remains usable with landscape keyboard and send failure',
    (tester) async {
      repo.failNextSend = true;
      await openChat(tester, repo, width: 812, height: 375);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      final composer = find.byKey(const ValueKey('message-composer'));
      await tester.enterText(composer, 'Can I collect my order at 12:30?');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('send-message')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('send-message')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Can I collect my order at 12:30?'), findsOneWidget);
      expect(repo.sendIds, hasLength(1));
      expect(repo.stored, isEmpty);
    },
  );
}
