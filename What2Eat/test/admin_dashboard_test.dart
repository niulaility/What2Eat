import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:what2eat_starter/features/admin/admin_dashboard_page.dart';
import 'package:what2eat_starter/features/admin/vendor_application_details_page.dart';
import 'package:what2eat_starter/features/admin/vendor_application_preview_data.dart';
import 'package:what2eat_starter/features/profile/account_page.dart';
import 'package:what2eat_starter/features/profile/edit_profile_page.dart';

import 'support/profile_fixture.dart';

Future<void> openDashboard(
  WidgetTester tester, {
  double width = 411,
  double scale = 1,
  SampleProfileRepository? repository,
}) async {
  tester.view.physicalSize = Size(width, 891);
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
      home: AdminDashboardPage(
        name: 'Admin Test',
        profileRepository: repository,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Reviews filters all statuses and completed decisions are read-only',
    (tester) async {
      await openDashboard(tester);
      await tester.tap(find.byKey(const ValueKey('admin-tab-Reviews')));
      await tester.pumpAndSettle();
      expect(find.text('Vendor application reviews'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-W2E-V-0001')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-W2E-V-0006')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reviews-filter-approved')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-W2E-V-0001')), findsNothing);
      expect(find.byKey(const ValueKey('review-W2E-V-0004')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reviews-filter-rejected')));
      await tester.pumpAndSettle();
      final rejected = find.byKey(const ValueKey('review-W2E-V-0006'));
      await tester.ensureVisible(rejected);
      await tester.tap(rejected);
      await tester.pumpAndSettle();
      expect(find.text('Sample application · Rejected'), findsOneWidget);
      expect(find.text('Reason for rejection'), findsOneWidget);
      expect(find.byKey(const ValueKey('approve-application')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reviews-filter-pending')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-W2E-V-0001')), findsOneWidget);
      expect(find.byKey(const ValueKey('review-W2E-V-0006')), findsNothing);
    },
  );

  testWidgets('Account tabs and search separate customers from vendors', (
    tester,
  ) async {
    await openDashboard(tester);
    await tester.tap(find.byKey(const ValueKey('admin-tab-Accounts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-C001')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-V001')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('accounts-filter-Vendor')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-C001')), findsNothing);
    expect(find.byKey(const ValueKey('account-V001')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('account-search')),
      'morning',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-V002')), findsOneWidget);
    expect(find.byKey(const ValueKey('account-V001')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('account-search')),
      'no matches',
    );
    await tester.pumpAndSettle();
    expect(find.text('No accounts match your search.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('admin-tab-Home')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, Admin! 👋'), findsOneWidget);
  });

  for (final size in [(320.0, 1.0), (320.0, 1.6), (411.0, 1.4), (900.0, 1.0)]) {
    testWidgets('Admin home fits ${size.$1} width and ${size.$2} text scale', (
      tester,
    ) async {
      // No Supabase initialization: the dashboard must not load or modify users.
      await openDashboard(tester, width: size.$1, scale: size.$2);
      expect(find.text('Pending vendor applications'), findsOneWidget);
      expect(find.text('What2Eat'), findsOneWidget);
      expect(find.byIcon(Icons.ramen_dining_rounded), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-tab-Home')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-tab-Reviews')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-tab-Accounts')), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('toggle-applications')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home shows two cards and locally expands without other pages', (
    tester,
  ) async {
    await openDashboard(tester);
    final third = find.byKey(const ValueKey('admin-application-003'));
    expect(find.byKey(const ValueKey('admin-application-001')), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-application-002')), findsOneWidget);
    expect(third, findsNothing);
    expect(find.byKey(const ValueKey('admin-welcome-panel')), findsNothing);
    expect(find.byKey(const ValueKey('new-accounts-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pending-applications-panel')),
      findsOneWidget,
    );
    expect(
      find.text(vendorApplicationPreviews.first.campuses.first),
      findsNothing,
    );
    expect(find.text('Pending review'), findsNothing);
    final toggle = find.byKey(const ValueKey('toggle-applications'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(third, findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(third, findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets(
    'Application details open while other management tabs remain previews',
    (tester) async {
      await openDashboard(tester);
      for (final tab in ['Settings']) {
        expect(
          tester.widget<InkWell>(find.byKey(ValueKey('admin-tab-$tab'))).onTap,
          isNull,
        );
      }
      final card = find.byKey(const ValueKey('admin-application-001'));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(VendorApplicationDetailsPage), findsOneWidget);
      expect(find.text('Business details'), findsOneWidget);
      expect(find.text('Fresh Campus Kitchen'), findsWidgets);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      final fields = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((text) => text.data);
      expect(
        fields,
        containsAll([
          vendorApplicationPreviews.first.owner,
          vendorApplicationPreviews.first.email,
          vendorApplicationPreviews.first.address,
          vendorApplicationPreviews.first.description,
        ]),
      );
      expect(
        find.byKey(const ValueKey('approve-application')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('reject-application')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm preview'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a reason for the applicant.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Please supply a clearer document.',
      );
      await tester.tap(find.text('Confirm preview'));
      await tester.pumpAndSettle();
      expect(
        find.text('Preview complete. The application is still pending.'),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-application-001')),
        findsOneWidget,
      );
    },
  );

  for (final size in [(320.0, 1.0), (411.0, 1.4)]) {
    testWidgets(
      'Sample application details and document preview fit ${size.$1}',
      (tester) async {
        await openDashboard(tester, width: size.$1, scale: size.$2);
        final card = find.byKey(const ValueKey('admin-application-001'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        final document = find.byKey(const ValueKey('document-ic-front'));
        await tester.scrollUntilVisible(
          document,
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('application-details-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(document);
        await tester.pumpAndSettle();
        expect(find.text('Sample document 1'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('approve-application')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Existing profile editing and save remain accessible at top right',
    (tester) async {
      final repository = SampleProfileRepository(role: 'admin');
      await openDashboard(tester, repository: repository);
      expect(
        tester.getCenter(find.byTooltip('Account options')).dx,
        greaterThan(350),
      );
      await tester.tap(find.byTooltip('Account options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountPage), findsOneWidget);
      await tester.ensureVisible(find.text('Edit profile'));
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Updated Admin',
      );
      final save = find.byKey(const ValueKey('save-profile'));
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('profile-form')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.saves, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, Updated! 👋'), findsOneWidget);
    },
  );
}
