# What2Eat

What2Eat is a campus food pre-ordering app. Students browse home-based and
campus food vendors serving their university, check each vendor's menu for a
meal session, and message vendors directly. Vendors apply with verification
documents, and administrators review those applications before a vendor can
start selling.

Built with **Flutter** (Android first) and **Supabase** (Postgres, Auth,
Storage and Edge Functions).

## Features

### Students
- Sign up with a university, then sign in with a username or email
- Reset a forgotten password by email
- Browse approved vendors serving their campus, filter by date and search by name
- View vendor profiles, meal-session menus and food details with customizations
- Message vendors in the app
- Edit their profile and profile picture

### Vendors
- Apply in three steps: account, business details and verification documents
- See application status while waiting for review, and get an email with the decision
- Manage menus, food items, categories and customizations
  *(in progress: changes currently stay on the device)*
- Reply to student messages

### Administrators
- Review vendor applications with their submitted documents
- Approve or reject applications; the applicant is emailed the decision
- Manage accounts and supported universities *(in progress: preview screens)*

## Tech stack

| Area | Technology |
| --- | --- |
| App | Flutter 3.47 / Dart 3.13, Material 3 |
| Backend | Supabase: Postgres with row-level security, Auth, Storage |
| Server logic | Postgres functions and Supabase Edge Functions (Deno) |
| Email | Resend, called from Edge Functions |

## Getting started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.47 or newer
- Android Studio with an emulator, or an Android phone with USB debugging on
- [Supabase CLI](https://supabase.com/docs/guides/cli) (only needed for backend changes)

### Run the app

```bash
git clone https://github.com/niulaility/What2Eat.git
cd What2Eat
flutter pub get
flutter run
```

The app connects to the team's hosted Supabase project by default. To point it
at another project, copy `.env.example` to `.env`, fill in that project's URL
and **publishable** key, and run:

```bash
flutter run --dart-define-from-file=.env
```

`.env` is ignored by Git. Never put a service-role or secret key in the app.

In Android Studio, choose **Open** and select the repository root (the folder
containing `pubspec.yaml`).

## Project structure

```text
lib/
  main.dart               App entry point and Supabase setup
  features/
    authentication/       Sign in, registration, password reset
    student/              Vendor discovery, menus and food details
    vendor/               Vendor dashboard, menus and food editor
    admin/                Application reviews, accounts, universities
    messaging/            Student–vendor chat
    profile/              Account and profile editing
  shared/                 Widgets shared across features
supabase/
  migrations/             Database schema, policies and functions
  functions/              Edge Functions (vendor sign-up and emails)
  seed.sql                Test accounts for a local database
test/                     Widget and unit tests
tools/                    Backend security test scripts
```

## Backend setup

Only needed when setting up a new Supabase project or changing the backend.

1. **Database:** apply every file in `supabase/migrations` in order. With the
   CLI linked to the project, run `supabase db push`. Alternatively, paste each
   file into the Supabase Dashboard's **SQL Editor** and run it.
2. **Vendor approval hook:** in **Authentication → Hooks**, add a **Custom
   Access Token** hook using `public.enforce_vendor_approval_for_auth`. This
   stops pending and rejected vendors from signing in.
3. **Email confirmation:** keep it enabled for students. Vendor accounts are
   confirmed by the `vendor-create-account` function instead.
4. **Password reset redirect:** in **Authentication → URL Configuration**, add
   `what2eat://login-callback/` to **Redirect URLs**.
5. **Edge Functions and email:**

   ```bash
   supabase secrets set RESEND_API_KEY=re_your_key RESEND_FROM_EMAIL="What2Eat <no-reply@your-domain>"
   supabase functions deploy vendor-create-account --no-verify-jwt
   supabase functions deploy vendor-application-received
   supabase functions deploy vendor-review-notification
   ```

   The sender address must belong to a domain verified in Resend. Keep the
   Resend key in Supabase secrets only, never in the app.

`supabase/seed.sql` creates an admin, a student and a vendor account for local
development. The login details are in that file.

## Testing

```bash
flutter analyze
flutter test
```

Widget tests use fake repositories and never touch the hosted database.

## Troubleshooting

- **Kotlin "incremental cache" errors on Windows:** `android/gradle.properties`
  already turns off Kotlin incremental compilation to avoid them. Builds can be
  slower after dependency changes.
- **Sign-up fails with "Supabase could not save the new account":** a migration
  is missing on the project. Apply all files in `supabase/migrations`, then
  fully restart the app.
- **Password reset email arrives but the link does nothing:** check the
  redirect URL in step 4 of the backend setup.

## Related

- Password reset web page:
  [Edwin0519/what2eat-password-reset](https://github.com/Edwin0519/what2eat-password-reset)
  (live at https://what2eat-password-reset.vercel.app/)

## License

Released under the [GNU General Public License v3.0](LICENSE).
