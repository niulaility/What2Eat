# What2Eat Flutter Starter

This is a blank Android Flutter project with one starter screen. Put your first
screen in lib/main.dart.

## Open in Android Studio

1. Extract the ZIP. Choose Open and select the what2eat_starter folder
   containing pubspec.yaml.
2. Enable the Flutter and Dart plugins and select your Flutter SDK if prompted.
3. Start an Android emulator in Device Manager.
4. Open the Android Studio terminal and run:

   ```powershell
   flutter pub get
   flutter devices
   flutter run
   ```

   If several devices are listed, select the Android emulator in the toolbar
   and run lib/main.dart, or use flutter run -d followed by its device ID.

The app opens the What2Eat login interface. Use the shared Username/Email and password sign-in page. Choose Sign up for customer or Sign up for vendors to open separate registration forms. Role detection awaits authentication integration. Password visibility and checkboxes are local UI state. Submission, recovery, and policy links display preview messages; no authentication or Supabase calls are made.

## Starter folders

Use lib/features for feature code and supabase for future database files.
The folders contain placeholders so Git preserves them.

## 4. Prepare shared configuration for all teammates

Commit .env.example so everyone has the same template. Each teammate copies it
to .env and fills in the Supabase project URL and publishable key for the team
project. Keep .env out of Git and use only a publishable key in the app.

When you add Supabase initialization in Dart, read these values using
String.fromEnvironment and run Flutter with --dart-define-from-file=.env.
The starter screen runs without configuration until Supabase is added.

## Password reset

The **Forgot password?** flow sends a Supabase Auth recovery email and returns
the customer to the app to set a new password. In the Supabase Dashboard, open
**Authentication → URL Configuration** and add this exact value to **Redirect
URLs**:

```text
what2eat://login-callback/
```

Keep the Supabase Auth password recovery email template enabled and use its
`{{ .ConfirmationURL }}` link (or the dashboard's equivalent default recovery
link). Supabase verifies the one-time recovery link before the app displays the
new-password form. Unknown email addresses receive the same in-app confirmation
message as registered accounts to avoid account enumeration. Supabase's Auth
rate limits remain in force, with an additional short resend cooldown in the
app.

The redirect can be overridden for a different app scheme with
`--dart-define=PASSWORD_RESET_REDIRECT_URL=your-scheme://login-callback/`; add
that exact redirect to the Supabase allow-list and register the matching native
URL scheme before using it.


