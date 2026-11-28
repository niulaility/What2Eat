import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:what2eat_starter/features/profile/account_page.dart';
import 'package:what2eat_starter/features/profile/edit_profile_page.dart';
import 'package:what2eat_starter/features/profile/profile_widgets.dart';
import 'package:what2eat_starter/features/profile/user_profile.dart';
import 'package:what2eat_starter/features/student/customer_dashboard_page.dart';
import 'package:what2eat_starter/features/vendor/vendor_dashboard_page.dart';

import 'support/profile_fixture.dart';

Finder get formScroll => find
    .descendant(
      of: find.byKey(const ValueKey('profile-form')),
      matching: find.byType(Scrollable),
    )
    .first;
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 250, scrollable: formScroll);
  await tester.pumpAndSettle();
}

Future<void> openEditor(
  WidgetTester tester,
  SampleProfileRepository repository, {
  Future<XFile?> Function()? picker,
  Brightness brightness = Brightness.light,
  Size size = const Size(411, 891),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<UserProfile>(
                  builder: (_) => EditProfilePage(
                    profile: repository.current,
                    repository: repository,
                    pickImage: picker ?? () async => null,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> selectPhoto(WidgetTester tester) async {
  await tester.tap(find.text('Edit photo'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(find.text('Choose from gallery'));
    await Future<void>.delayed(const Duration(milliseconds: 80));
  });
  await tester.pumpAndSettle();
  for (
    var i = 0;
    i < 20 && find.text('Preview profile photo').evaluate().isEmpty;
    i++
  ) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Future<void> save(WidgetTester tester) async {
  await reveal(tester, find.byKey(const ValueKey('save-profile')));
  await tester.tap(find.byKey(const ValueKey('save-profile')));
  await tester.pumpAndSettle();
}

void main() {
  late Uint8List jpgBytes, pngBytes;
  setUpAll(() async {
    jpgBytes = await File('test/fixtures/profile-test.jpg').readAsBytes();
    pngBytes = await File('test/fixtures/profile-test.png').readAsBytes();
  });
  for (final role in ['student', 'vendor', 'admin']) {
    testWidgets(
      '$role edits personal fields while retaining role and sign-in email',
      (tester) async {
        final repository = SampleProfileRepository(role: role);
        await openEditor(tester, repository);
        final originalEmail = repository.current.email;
        await tester.enterText(
          find.byKey(const ValueKey('profile-name')),
          'Updated Demo Name',
        );
        await tester.enterText(
          find.byKey(const ValueKey('profile-username')),
          '${role}_updated',
        );
        await reveal(tester, find.byKey(const ValueKey('profile-phone')));
        await tester.enterText(
          find.byKey(const ValueKey('profile-phone')),
          '+60 19 887 7665',
        );
        await save(tester);
        expect(repository.saves, 1);
        expect(repository.current.fullName, 'Updated Demo Name');
        expect(repository.current.username, '${role}_updated');
        expect(repository.current.phone, '+60198877665');
        expect(repository.current.email, originalEmail);
        expect(repository.current.role, role);
        expect(find.text('Open editor'), findsOneWidget);
      },
    );
  }
  testWidgets('student changes university using the directory', (tester) async {
    final repository = SampleProfileRepository();
    await openEditor(tester, repository);
    await reveal(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('Universiti Teknologi Malaysia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Universiti Malaya').last);
    await tester.pumpAndSettle();
    await save(tester);
    expect(repository.current.universityId, 'campus-um');
  });
  testWidgets(
    'unchanged profile cannot be submitted; email remains read-only',
    (tester) async {
      final repository = SampleProfileRepository();
      await openEditor(tester, repository);
      await reveal(tester, find.text('Email address'));
      final emailField = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == repository.current.email,
      );
      expect(tester.widget<EditableText>(emailField).readOnly, isTrue);
      await reveal(tester, find.byKey(const ValueKey('save-profile')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('save-profile')))
            .onPressed,
        isNull,
      );
      expect(repository.saves, 0);
    },
  );
  testWidgets('invalid phone and name cannot be saved', (tester) async {
    final repository = SampleProfileRepository();
    await openEditor(tester, repository);
    await tester.enterText(find.byKey(const ValueKey('profile-name')), 'A');
    await reveal(tester, find.byKey(const ValueKey('profile-phone')));
    await tester.enterText(find.byKey(const ValueKey('profile-phone')), 'abc');
    await save(tester);
    expect(repository.saves, 0);
    expect(find.textContaining('Use digits with an optional'), findsOneWidget);
  });
  testWidgets('duplicate username and network failure never show success', (
    tester,
  ) async {
    final repository = SampleProfileRepository()..duplicateUsername = true;
    await openEditor(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('profile-username')),
      'already_taken',
    );
    await save(tester);
    expect(
      find.textContaining('That username is already taken'),
      findsOneWidget,
    );
    expect(repository.current.username, 'student_demo');
    repository.duplicateUsername = false;
    repository.failSave = true;
    tester.state<ScrollableState>(formScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-username')),
      'another_name',
    );
    await save(tester);
    expect(find.textContaining('Could not save your profile'), findsOneWidget);
    expect(find.text('Your profile has been updated.'), findsNothing);
  });
  testWidgets('repeated Save taps produce a single in-flight update', (
    tester,
  ) async {
    final repository = SampleProfileRepository()
      ..saveDelay = const Duration(seconds: 1);
    await openEditor(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'One Save',
    );
    await reveal(tester, find.byKey(const ValueKey('save-profile')));
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.tap(find.byKey(const ValueKey('save-profile')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(repository.saves, 1);
    expect(find.text('Saving…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
  testWidgets('Back asks before discarding and does not save', (tester) async {
    final repository = SampleProfileRepository();
    await openEditor(tester, repository);
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Unsaved Name',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved Name'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.saves, 0);
    expect(repository.current.fullName, 'Sara Abdullah');
    expect(find.text('Open editor'), findsOneWidget);
  });
  for (final extension in ['jpg', 'png']) {
    testWidgets(
      '$extension preview can be cancelled and confirmed before upload',
      (tester) async {
        final bytes = extension == 'jpg' ? jpgBytes : pngBytes;
        final repository = SampleProfileRepository();
        await openEditor(
          tester,
          repository,
          picker: () async => XFile.fromData(bytes, name: 'test.$extension'),
        );
        await selectPhoto(tester);
        expect(find.text('Preview profile photo'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await tester.pumpAndSettle();
        expect(repository.uploads, 0);
        await selectPhoto(tester);
        await tester.tap(find.text('Use photo'));
        await tester.pumpAndSettle();
        expect(repository.uploads, 0);
        await save(tester);
        expect(repository.uploads, 1);
        expect(repository.current.avatarPath, endsWith('.$extension'));
      },
    );
  }
  testWidgets('cancelled native-picker result leaves profile unchanged', (
    tester,
  ) async {
    final repository = SampleProfileRepository();
    await openEditor(tester, repository);
    await selectPhoto(tester);
    await reveal(tester, find.byKey(const ValueKey('save-profile')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-profile')))
          .onPressed,
      isNull,
    );
    expect(repository.uploads, 0);
  });
  testWidgets('unsupported and oversized selections do not upload', (
    tester,
  ) async {
    final repository = SampleProfileRepository();
    var bytes = Uint8List.fromList([1, 2, 3]);
    await openEditor(
      tester,
      repository,
      picker: () async => XFile.fromData(bytes, name: 'fake.jpg'),
    );
    await selectPhoto(tester);
    await reveal(tester, find.byKey(const ValueKey('save-profile')));
    expect(find.text('Choose a valid JPEG or PNG photo.'), findsOneWidget);
    tester.state<ScrollableState>(formScroll).position.jumpTo(0);
    await tester.pumpAndSettle();
    bytes = Uint8List(5 * 1024 * 1024 + 1);
    await selectPhoto(tester);
    await reveal(tester, find.byKey(const ValueKey('save-profile')));
    expect(find.text('Choose a photo smaller than 5 MB.'), findsOneWidget);
    expect(repository.uploads, 0);
  });
  testWidgets('failed upload keeps the saved avatar reference unchanged', (
    tester,
  ) async {
    final bytes = pngBytes;
    final repository = SampleProfileRepository(avatarPath: 'old-image')
      ..failUpload = true;
    await openEditor(
      tester,
      repository,
      picker: () async => XFile.fromData(bytes, name: 'photo.png'),
    );
    await selectPhoto(tester);
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(repository.current.avatarPath, 'old-image');
    expect(repository.saves, 0);
    expect(find.textContaining('Could not access your photo'), findsOneWidget);
  });
  testWidgets('a failed profile save reuses the uploaded image on retry', (
    tester,
  ) async {
    final bytes = pngBytes;
    final repository = SampleProfileRepository()..failSave = true;
    await openEditor(
      tester,
      repository,
      picker: () async => XFile.fromData(bytes, name: 'photo.png'),
    );
    await selectPhoto(tester);
    await tester.tap(find.text('Use photo'));
    await tester.pumpAndSettle();
    await save(tester);
    expect(repository.uploads, 1);
    repository.failSave = false;
    await save(tester);
    expect(repository.uploads, 1);
    expect(repository.saves, 2);
  });
  testWidgets('removing a photo unlinks it without deleting uploaded files', (
    tester,
  ) async {
    final repository = SampleProfileRepository(avatarPath: 'saved-image');
    repository.images['saved-image'] = pngBytes;
    await openEditor(tester, repository);
    await tester.tap(find.text('Edit photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await save(tester);
    expect(repository.current.avatarPath, isNull);
    expect(repository.images.containsKey('saved-image'), isTrue);
  });
  testWidgets('small light screen scrolls to Save without overflow', (
    tester,
  ) async {
    await openEditor(
      tester,
      SampleProfileRepository(),
      size: const Size(320, 640),
    );
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Dark Mode Demo',
    );
    await reveal(tester, find.byKey(const ValueKey('save-profile')));
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byKey(const ValueKey('save-profile')));
    expect(Theme.of(context).brightness, Brightness.light);
  });
  testWidgets('image download failure displays a default avatar', (
    tester,
  ) async {
    final repository = SampleProfileRepository(avatarPath: 'broken')
      ..failRead = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAvatar(repository: repository, reference: 'broken'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Account immediately shows saved details and reloads them', (
    tester,
  ) async {
    final repository = SampleProfileRepository();
    await tester.pumpWidget(
      MaterialApp(home: AccountPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Edit profile'));
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-name')),
      'Saved Account Name',
    );
    await save(tester);
    expect(find.text('Your profile has been updated.'), findsOneWidget);
    expect(find.text('Saved Account Name'), findsWidgets);
    await tester.tap(find.byTooltip('Refresh profile'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Account Name'), findsWidgets);
  });
  for (final dashboard in <Widget>[
    const CustomerDashboardPage(name: 'Student Demo'),
    const VendorDashboardPage(name: 'Vendor Demo'),
  ]) {
    testWidgets(
      '${dashboard.runtimeType} has one account entry at the top right',
      (tester) async {
        await tester.pumpWidget(MaterialApp(home: dashboard));
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.leading, isNull);
        expect(appBar.actions?.whereType<PopupMenuButton<String>>().length, 1);
        expect(
          tester.getCenter(find.byTooltip('Account options')).dx,
          greaterThan(
            tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
          ),
        );
        expect(find.byType(PopupMenuButton<String>), findsOneWidget);
        await tester.tap(find.byTooltip('Account options'));
        await tester.pumpAndSettle();
        expect(find.text('Profile'), findsOneWidget);
        expect(find.text('Logout'), findsOneWidget);
      },
    );
  }
}
