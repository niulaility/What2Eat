# What2Eat

Campus food pre-ordering app for university students, vendors and
administrators, built with Flutter and Supabase.

## Project layout

- `lib/` – Flutter app code, grouped by feature under `lib/features/`
- `test/` – widget and unit tests (`flutter test`)
- `supabase/` – database migrations, seed data and Edge Functions
- `android/`, `ios/`, `macos/` – platform projects
- `assets/` – bundled images

## Open in Android Studio

1. Clone the repository. Choose Open and select the repository root folder
   (the one containing pubspec.yaml).
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

The app opens the What2Eat login interface. Choose customer or vendor registration to create an account through Supabase. Email confirmation is required by the hosted project.

## Windows Kotlin cache errors

`android/gradle.properties` disables Kotlin incremental compilation and runs the
compiler in the Gradle process. This avoids the incremental-cache close errors
seen in Android dependencies with this Windows checkout and its dependency
cache. These settings apply to normal `flutter run` and APK builds; Kotlin
compilation may take longer when dependency sources change.

Password reset website source and deployment instructions are maintained in
[Edwin0519/what2eat-password-reset](https://github.com/Edwin0519/what2eat-password-reset).
The live page is https://what2eat-password-reset.vercel.app/ .
A successful reset request does not prove email
delivery; use an existing What2Eat customer account and verify the email link,
password update, and subsequent sign-in before treating the flow as complete.

## Supabase setup

Commit .env.example so everyone has the same template. Each teammate copies it
to .env and fills in the Supabase project URL and publishable key for the team
project. Keep .env out of Git and use only a publishable key in the app.

The app reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` from
`String.fromEnvironment`. The committed `.env.example` is JSON, so a local `.env`
can be passed with `flutter run --dart-define-from-file=.env`.

Apply the SQL files in `supabase/migrations` to the hosted project before
registering users. To apply a pending migration manually, open the project's
Supabase Dashboard, choose **SQL Editor**, create a query, paste the full SQL
file contents, and run it. For this signup-trigger fix, run
`supabase/migrations/20261116000005_harden_auth_user_trigger.sql`.

To require administrator approval before vendor sign-in, also run
`supabase/migrations/20261116000008_vendor_admin_approval.sql` and
`supabase/migrations/20261116000009_vendor_signup_rate_limit.sql` and
`supabase/migrations/20261116000010_protect_profile_roles.sql` and
`supabase/migrations/20261116000011_remove_vendor_signup_rate_limit.sql`. Then open
**Authentication → Hooks** in the Supabase Dashboard, add a **Custom Access
Token** hook, and select `public.enforce_vendor_approval_for_auth`. Save and
enable the hook. Pending and rejected vendors will be blocked from receiving
new or refreshed access tokens; vendors without an application row can still
finish registration. The vendor-only account creation function confirms new
vendor email addresses server-side, so leave the project's global email
confirmation setting enabled for students. The admin dashboard can inspect
submitted documents and approve or reject pending applications.

To email vendors when their applications are received, set the Edge Function
secrets in the linked Supabase project and deploy the function:

```powershell
supabase secrets set RESEND_API_KEY=re_your_resend_api_key RESEND_FROM_EMAIL="What2Eat <no-reply@auth.w11x.my>"
supabase functions deploy vendor-create-account --no-verify-jwt
supabase functions deploy vendor-application-received
supabase functions deploy vendor-review-notification
```

Use the Resend API key as `RESEND_API_KEY`; do not put it in the Flutter app or
`.env`. Supabase injects the service-role key into Edge Functions; it must never
be added to the app. The sender address must belong to the verified sending
domain in Resend. The account-creation function uses the service-role key only
on the server. The receipt function sends
only to the authenticated vendor's own email after their pending application
has been saved. The review-notification function sends the approval or rejection
decision to the vendor after an administrator reviews the application. If that
email fails, the review remains saved and the admin dashboard shows a warning.

The publishable key only connects the app to Supabase APIs; it cannot apply
database migrations. After applying SQL, fully restart the app and retry signup.

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


