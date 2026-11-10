<<<<<<< HEAD
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

The screen should show “What2Eat Starter” and “Ready to build.”

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
=======
# What2Eat
>>>>>>> origin/main
