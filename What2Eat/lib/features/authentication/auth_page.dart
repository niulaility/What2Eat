import 'vendor_registration_page.dart';
import 'registration_success_page.dart';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../student/customer_dashboard_page.dart';
import '../vendor/vendor_dashboard_page.dart';
import '../admin/admin_dashboard_page.dart';

import 'registration_validators.dart';
import 'password_reset_page.dart';
import 'forgot_password_page.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.registrationRole});
  final String? registrationRole;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool hidden = true, confirmHidden = true, remember = false, agreed = false;
  final customerFormKey = GlobalKey<FormState>();
  final confirmationKey = GlobalKey<FormFieldState<String>>();
  bool confirmationEdited = false;
  final registrationPassword = TextEditingController();
  final studentFullName = TextEditingController();
  final studentUsername = TextEditingController();
  final studentEmail = TextEditingController();
  final studentPhone = TextEditingController();
  final signInIdentifier = TextEditingController();
  final signInPassword = TextEditingController();
  bool isSigningIn = false;
  bool isRegistering = false;
  bool submitted = false;
  Uint8List? profilePhoto;
  String? university;
  bool pickingPhoto = false;
  bool get register => widget.registrationRole != null;
  bool get vendor => widget.registrationRole == 'vendor';

  @override
  void dispose() {
    registrationPassword.dispose();
    studentFullName.dispose();
    studentUsername.dispose();
    studentEmail.dispose();
    studentPhone.dispose();
    signInIdentifier.dispose();
    signInPassword.dispose();
    super.dispose();
  }

  Future<void> submitCustomerRegistration() async {
    if (isRegistering) return;
    setState(() => submitted = true);
    final valid = customerFormKey.currentState!.validate();
    if (!valid || !agreed) return;
    FocusScope.of(context).unfocus();
    setState(() => isRegistering = true);
    try {
      final client = Supabase.instance.client;
      final existingEmail = await client.rpc(
        'get_email_by_username',
        params: {'p_username': studentUsername.text.trim()},
      );
      final email = studentEmail.text.trim().toLowerCase();
      if (existingEmail is String && existingEmail.isNotEmpty) {
        if (mounted) {
          preview(existingEmail.toLowerCase() == email
              ? 'An account already uses this email. Please sign in.'
              : 'That username is already taken. Choose another one.');
        }
        return;
      }
      final response = await client.auth.signUp(
        email: email,
        password: registrationPassword.text,
        data: {
          'role': 'student',
          'username': studentUsername.text.trim(),
          'full_name': studentFullName.text.trim(),
          'phone_number': studentPhone.text.trim(),
          'university': university == 'other' ? null : university,
          'terms_accepted': true,
        },
      );
      if (!mounted) return;
      if (response.user == null) {
        throw const AuthException('Registration failed. Please try again.');
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RegistrationSuccessPage(
            emailConfirmationRequired: response.session == null,
            email: email,
          ),
        ),
      );
    } on AuthException catch (error) {
      debugPrint('Student signup AuthException: $error');
      if (mounted) preview(registrationAuthError(error));
    } catch (error) {
      debugPrint('Student registration failed: $error');
      if (mounted) preview('Could not create your account: $error');
    } finally {
      if (mounted) setState(() => isRegistering = false);
    }
  }

  void preview(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String registrationAuthError(AuthException error) {
    if (error.statusCode == '500' && error.code == 'unexpected_failure') {
      return 'Supabase could not save the new account. Apply the latest SQL migration in supabase/migrations, then retry.';
    }
    final details = <String>[
      error.message,
      if (error.code != null) 'code: ${error.code}',
      if (error.statusCode != null) 'HTTP ${error.statusCode}',
    ];
    return details.join(' · ');
  }

  Future<void> signIn() async {
    final identifier = signInIdentifier.text.trim();
    final password = signInPassword.text;

    if (identifier.isEmpty || password.isEmpty) {
      preview('Please enter your username/email and password.');
      return;
    }

    setState(() => isSigningIn = true);

    try {
      String email = identifier;

      // If username entered, resolve to email via SECURITY DEFINER RPC
      if (!identifier.contains('@')) {
        final result = await Supabase.instance.client
            .rpc('get_email_by_username', params: {'p_username': identifier});

        if (result == null || (result as String).isEmpty) {
          throw const AuthException('No account found with this username.');
        }
        email = result as String;
      }

      // Authenticate
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign in failed. Please try again.');
      }

      // Fetch role and name from profiles
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role, full_name, username')
          .eq('id', user.id)
          .single();

      final role = profile['role'] as String? ?? 'student';
      final name = (profile['full_name'] as String?)?.trim().isNotEmpty == true
          ? profile['full_name'] as String
          : (profile['username'] as String? ?? 'User');

      if (role == 'vendor') {
        final application = await Supabase.instance.client
            .from('vendors')
            .select('status, is_active')
            .eq('user_id', user.id)
            .maybeSingle();
        if (application == null) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            preview('Submit your vendor application before signing in.');
          }
          return;
        }
        if (application['status'] != 'approved' ||
            application['is_active'] != true) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            preview(
                'Your vendor application is being reviewed by an administrator. You can sign in after it is approved.');
          }
          return;
        }
      }

      if (!mounted) return;

      // Navigate to respective dashboard
      Widget destination;
      switch (role) {
        case 'admin':
          destination = AdminDashboardPage(name: name);
          break;
        case 'vendor':
          destination = VendorDashboardPage(name: name);
          break;
        case 'student':
        default:
          destination = CustomerDashboardPage(name: name);
          break;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => destination),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (mounted) {
        final detail = e.message.toLowerCase();
        if (detail.contains('vendor application was rejected')) {
          preview(
              'Your vendor application was rejected. Please contact What2Eat for assistance.');
        } else if (detail.contains('awaiting administrator approval') ||
            detail.contains('vendor application is awaiting')) {
          preview(
              'Your vendor application is being reviewed by an administrator. You can sign in after it is approved.');
        } else {
          preview(e.message);
        }
      }
    } catch (e) {
      if (mounted) preview('Sign in failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => isSigningIn = false);
    }
  }

  void openRegistration(String role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => role == 'vendor'
            ? const VendorRegistrationPage()
            : AuthPage(registrationRole: role),
      ),
    );
  }

  Widget field(
    String label,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    bool password = false,
    bool confirmation = false,
    TextEditingController? controller,
  }) {
    final obscure = confirmation ? confirmHidden : hidden;
    final customer = register && !vendor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: customer && confirmation ? confirmationKey : null,
            autovalidateMode: customer
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            onChanged: !customer
                ? null
                : (value) {
                    if (confirmation) confirmationEdited = true;
                    if (password &&
                        !confirmation &&
                        (confirmationEdited || submitted)) {
                      confirmationKey.currentState?.validate();
                    }
                  },
            controller: controller ??
                (customer && password && !confirmation
                    ? registrationPassword
                    : null),
            validator: !customer
                ? null
                : switch (label) {
                    'Full name' => (value) {
                        final name = (value ?? '').trim();
                        if (name.isEmpty) return 'Enter your full name.';
                        if (name.length < 2 || name.length > 100) {
                          return 'Use 2–100 characters.';
                        }
                        return null;
                      },
                    'Username' => RegistrationValidators.username,
                    'Email address' => RegistrationValidators.email,
                    'Phone number' => RegistrationValidators.phone,
                    'Password' => RegistrationValidators.password,
                    'Confirm password' => (value) =>
                        RegistrationValidators.confirmation(
                          value,
                          registrationPassword.text,
                        ),
                    _ => null,
                  },
            inputFormatters: label == 'Phone number'
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ]
                : null,
            keyboardType: keyboard,
            obscureText: password && obscure,
            autocorrect: !password && keyboard == null,
            enableSuggestions: !password,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              errorMaxLines: 3,
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: Color(0xFF92978B),
              ),
              prefixIcon: Icon(icon, size: 20),
              suffixIcon: password
                  ? IconButton(
                      tooltip: obscure
                          ? 'Show ${label.toLowerCase()}'
                          : 'Hide ${label.toLowerCase()}',
                      onPressed: () => setState(() {
                        if (confirmation) {
                          confirmHidden = !confirmHidden;
                        } else {
                          hidden = !hidden;
                        }
                      }),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => register
      ? (vendor ? registrationPage() : customerRegistrationPage())
      : signInPage();

  Widget registrationPage() => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD85C),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child:
                              const Icon(Icons.ramen_dining_rounded, size: 28),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'What2Eat',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.wb_sunny_outlined,
                          color: Color(0xFF728053),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'HOMEMADE. CAMPUS-READY.',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF728053),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      register
                          ? 'Good food.\nNew beginnings.'
                          : 'Your next meal,\nmade closer.',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: -1.5,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      register && vendor
                          ? 'Bring your kitchen to the campus community.'
                          : 'Discover home-cooked favourites from your campus community.',
                      style: const TextStyle(
                        color: Color(0xFF74796C),
                        height: 1.5,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (register)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: const Text('Back to sign in'),
                        ),
                      ),
                    Text(
                      register
                          ? 'Create your ${vendor ? 'vendor' : 'customer'} account'
                          : 'Welcome back!',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      register
                          ? 'A few details and you’re on your way.'
                          : 'Sign in with your username or email to continue.',
                      style: const TextStyle(color: Color(0xFF74796C)),
                    ),
                    const SizedBox(height: 24),
                    if (register) ...[
                      field(
                        'Full name',
                        'Enter your full name',
                        Icons.person_outline,
                      ),
                      field('Username', 'Choose a username',
                          Icons.alternate_email),
                      if (vendor)
                        field(
                          'Kitchen / business name',
                          'e.g. Mama’s Kitchen',
                          Icons.storefront_outlined,
                        ),
                    ],
                    field(
                      register ? 'Email address' : 'Username/Email',
                      register
                          ? 'Enter your email address'
                          : 'Enter your username or email',
                      Icons.mail_outline,
                      keyboard: register
                          ? TextInputType.emailAddress
                          : TextInputType.text,
                    ),
                    if (register) ...[
                      field(
                        'Phone number',
                        'e.g. 012 345 6789',
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                      if (!vendor)
                        field(
                          'University / campus',
                          'Enter your university or campus',
                          Icons.school_outlined,
                        ),
                    ],
                    field(
                      'Password',
                      register ? 'Create a password' : 'Enter your password',
                      Icons.lock_outline,
                      password: true,
                    ),
                    if (register)
                      field(
                        'Confirm password',
                        'Re-enter your password',
                        Icons.lock_outline,
                        password: true,
                        confirmation: true,
                      ),
                    if (register && vendor)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF1E4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.verified_user_outlined, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vendor accounts are reviewed before kitchens can start accepting orders.',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (register)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: agreed,
                            onChanged: (v) =>
                                setState(() => agreed = v ?? false),
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'I agree to the ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                legal('Terms of Service'),
                                const Text(' and ',
                                    style: TextStyle(fontSize: 12)),
                                legal('Privacy Policy'),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: remember,
                                onChanged: (v) =>
                                    setState(() => remember = v ?? false),
                              ),
                              const Text(
                                'Remember me',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => preview(
                              'Password recovery is not connected in this interface preview.',
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD85C),
                        foregroundColor: const Color(0xFF253729),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => preview(
                        'Interface preview only — ${register ? 'registration' : 'login'} is not connected.',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            register ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                          ),
                          TextButton(
                            onPressed: () => preview(
                              'Password recovery is not connected in this interface preview.',
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD85C),
                        foregroundColor: const Color(0xFF253729),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => preview(
                        'Interface preview only — ${register ? 'registration' : 'login'} is not connected.',
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            register ? 'Create account' : 'Sign in',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (register)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Already have an account? Sign in'),
                      )
                    else ...[
                      const Center(
                        child: Text(
                          'New to What2Eat?',
                          style: TextStyle(color: Color(0xFF74796C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => openRegistration('customer'),
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Sign up for customer'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () => openRegistration('vendor'),
                        icon: const Icon(Icons.storefront_outlined),
                        label: const Text('Sign up for vendors'),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Made with care. Shared on campus.',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF7A816E)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> chooseProfilePhoto() async {
    if (pickingPhoto) return;
    setState(() => pickingPhoto = true);
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => profilePhoto = bytes);
    } catch (_) {
      if (mounted) {
        preview('Could not open this photo. Please try another image.');
      }
    } finally {
      if (mounted) setState(() => pickingPhoto = false);
    }
  }

  Widget customerRegistrationPage() => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Form(
                  key: customerFormKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          label: const Text('Back to sign in'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Semantics(
                          button: true,
                          label: 'Choose profile photo',
                          child: Tooltip(
                            message: 'Choose profile photo',
                            child: InkWell(
                              onTap: pickingPhoto ? null : chooseProfilePhoto,
                              customBorder: const CircleBorder(),
                              child: SizedBox(
                                width: 112,
                                height: 112,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFFECEEE3),
                                        backgroundImage: profilePhoto == null
                                            ? null
                                            : MemoryImage(profilePhoto!),
                                        child: pickingPhoto
                                            ? const CircularProgressIndicator()
                                            : profilePhoto == null
                                                ? const Icon(
                                                    Icons.person_outline,
                                                    size: 56,
                                                    color: Color(0xFF64705D),
                                                  )
                                                : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFD85C),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      field('Username', 'Choose a username',
                          Icons.person_outline),
                      field(
                        'Email address',
                        'Enter your email address',
                        Icons.mail_outline,
                        keyboard: TextInputType.emailAddress,
                      ),
                      field(
                        'Phone number',
                        'e.g. 0123456789',
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                      ),
                      field(
                        'Full name',
                        'Enter your full name',
                        Icons.person_outline,
                        controller: studentFullName,
                      ),
                      field(
                        'Username',
                        'Choose a username',
                        Icons.alternate_email,
                        controller: studentUsername,
                      ),
                      field(
                        'Email address',
                        'Enter your email address',
                        Icons.mail_outline,
                        keyboard: TextInputType.emailAddress,
                        controller: studentEmail,
                      ),
                      field(
                        'Phone number',
                        'e.g. 0123456789',
                        Icons.phone_outlined,
                        keyboard: TextInputType.phone,
                        controller: studentPhone,
                      ),
                      const Text(
                        'University',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        validator: (value) =>
                            value == null ? 'Select your university.' : null,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        initialValue: university,
                        isExpanded: true,
                        hint: const Text(
                          'Select your university',
                          style: TextStyle(fontSize: 14),
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.school_outlined, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'utm',
                            child: Text('Universiti Teknologi Malaysia'),
                          ),
                          DropdownMenuItem(
                            value: 'um',
                            child: Text('Universiti Malaya'),
                          ),
                          DropdownMenuItem(
                            value: 'upm',
                            child: Text('Universiti Putra Malaysia'),
                          ),
                          DropdownMenuItem(
                            value: 'ukm',
                            child: Text('Universiti Kebangsaan Malaysia'),
                          ),
                          DropdownMenuItem(
                            value: 'usm',
                            child: Text('Universiti Sains Malaysia'),
                          ),
                          DropdownMenuItem(
                            value: 'uitm',
                            child: Text('Universiti Teknologi MARA'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other university'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => university = value),
                      ),
                      const SizedBox(height: 18),
                      field(
                        'Password',
                        'Create a password',
                        Icons.lock_outline,
                        password: true,
                      ),
                      field(
                        'Confirm password',
                        'Re-enter your password',
                        Icons.lock_outline,
                        password: true,
                        confirmation: true,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: agreed,
                            semanticLabel:
                                'Agree to Terms of Service and Privacy Policy',
                            onChanged: (value) =>
                                setState(() => agreed = value ?? false),
                          ),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'I agree to the ',
                                  style: TextStyle(fontSize: 12),
                                ),
                                legal('Terms of Service'),
                                const Text(' and ',
                                    style: TextStyle(fontSize: 12)),
                                legal('Privacy Policy'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (submitted && !agreed)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 4),
                          child: Text(
                            'Accept the Terms of Service and Privacy Policy to continue.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD85C),
                          foregroundColor: const Color(0xFF253729),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed:
                            pickingPhoto ? null : submitCustomerRegistration,
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: pickingPhoto || isRegistering
                            ? null
                            : submitCustomerRegistration,
                        child: isRegistering
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Text(
                                'Create student account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
  Widget signInPage() => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD85C),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.ramen_dining_rounded, size: 52),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'What2Eat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Color(0xFF253729),
                      ),
                    ),
                    const SizedBox(height: 40),
                    field(
                      'Username/Email',
                      'Enter your username or email',
                      Icons.person_outline,
                      keyboard: TextInputType.text,
                      controller: signInIdentifier,
                    ),
                    field(
                      'Password',
                      'Enter your password',
                      Icons.lock_outline,
                      password: true,
                      controller: signInPassword,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD85C),
                        foregroundColor: const Color(0xFF253729),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isSigningIn ? null : signIn,
                      child: isSigningIn
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF253729),
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                        onPressed: isSigningIn
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD85C),
                        foregroundColor: const Color(0xFF253729),
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isSigningIn ? null : signIn,
                      child: isSigningIn
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF253729),
                              ),
                            )
                          : const Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child:
                              signUpButton('customer', 'Sign up for customer'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: signUpButton('vendor', 'Sign up for vendors'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget signUpButton(String role, String label) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => openRegistration(role),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      );
  Widget legal(String title) => TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          minimumSize: const Size(0, 40),
        ),
        onPressed: () =>
            preview('$title is not available in this interface preview.'),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            decoration: TextDecoration.underline,
          ),
        ),
      );
}
