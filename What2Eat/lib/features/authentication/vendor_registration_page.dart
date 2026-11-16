import 'vendor_application_pending_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'registration_validators.dart';

class VendorRegistrationPage extends StatefulWidget {
  const VendorRegistrationPage({super.key});
  @override
  State<VendorRegistrationPage> createState() => _VendorRegistrationPageState();
}

class _VendorRegistrationPageState extends State<VendorRegistrationPage> {
  final forms = List.generate(3, (_) => GlobalKey<FormState>());
  final password = TextEditingController();
  final fields = <String, TextEditingController>{};
  final confirmation = GlobalKey<FormFieldState<String>>();
  final universityField = GlobalKey<FormFieldState<Set<String>>>();
  final uploads = <String, List<Uint8List>>{};
  final uploadFields = <String, GlobalKey<FormFieldState<List<Uint8List>>>>{};
  final scroll = ScrollController();
  int step = 0;
  bool hidden = true, confirmHidden = true, confirmationEdited = false;
  bool agreed = false;
  bool registering = false;
  String? picking;
  static const titles = [
    'Account Information',
    'Business Information',
    'Document Verification',
  ];
  static const universities = [
    'Universiti Teknologi Malaysia',
    'Universiti Malaya',
    'Universiti Putra Malaysia',
    'Universiti Kebangsaan Malaysia',
    'Universiti Sains Malaysia',
    'Universiti Teknologi MARA',
    'Other university',
  ];

  @override
  void dispose() {
    password.dispose();
    for (final controller in fields.values) {
      controller.dispose();
    }
    scroll.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void moveTo(int value) {
    FocusScope.of(context).unfocus();
    setState(() => step = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> next() async {
    if (!forms[step].currentState!.validate()) return;
    if (step < 2) {
      moveTo(step + 1);
      return;
    }
    await registerVendor();
  }

  Future<void> registerVendor() async {
    if (registering) return;
    setState(() => registering = true);
    final client = Supabase.instance.client;
    final values =
        fields.map((key, controller) => MapEntry(key, controller.text.trim()));
    try {
      final existingEmail = await client.rpc(
        'get_email_by_username',
        params: {'p_username': values['Username']},
      );
      if (existingEmail is String && existingEmail.isNotEmpty) {
        if (existingEmail.toLowerCase() !=
            values['Email Address']!.toLowerCase()) {
          if (mounted) {
            message('That username is already taken. Choose another one.');
          }
          return;
        }
      }
      User? user;
      try {
        final response = await client.auth.signUp(
          email: values['Email Address']!.toLowerCase(),
          password: password.text,
          data: {
            'role': 'vendor',
            'username': values['Username'],
            'full_name': values['Full Name'],
            'phone_number': values['Phone Number'],
            'terms_accepted': true,
          },
        );
        user = response.user;
      } on AuthException catch (error) {
        final authMessage = error.message.toLowerCase();
        if (!authMessage.contains('already registered') &&
            !authMessage.contains('already exists') &&
            !authMessage.contains('user exists')) {
          rethrow;
        }
      }
      if (client.auth.currentSession == null) {
        try {
          final response = await client.auth.signInWithPassword(
            email: values['Email Address']!.toLowerCase(),
            password: password.text,
          );
          user = response.user;
        } on AuthException catch (error) {
          if (mounted) {
            message(error.message.toLowerCase().contains('not confirmed')
                ? 'Confirm your email, return to this form, then tap Register again.'
                : error.message);
          }
          return;
        }
      }
      user ??= client.auth.currentUser;
      if (user == null) {
        throw const AuthException('Account creation returned no user.');
      }
      final profile = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      if (profile['role'] != 'vendor') {
        throw const AuthException(
            'This email belongs to a non-vendor account. Use another email.');
      }
      final logoBytes = uploads['logo']?.first;
      String? logoUrl;
      if (logoBytes != null) {
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}_logo.jpg';
        await client.storage.from('vendor-logos').uploadBinary(path, logoBytes);
        logoUrl = client.storage.from('vendor-logos').getPublicUrl(path);
      }
      final vendor = await client
          .from('vendors')
          .upsert({
            'user_id': user.id,
            'business_name': values['Business Name'],
            'business_description': values['Business Description'],
            'business_contact_number': values['Business Contact Number'],
            'business_address': values['Business Address'],
            if (logoUrl != null) 'logo_url': logoUrl,
          }, onConflict: 'user_id')
          .select('id')
          .single();
      final available = await client
          .from('universities')
          .select('id, name')
          .eq('is_active', true);
      final chosen = universityField.currentState!.value ?? <String>{};
      final selected = (available as List)
          .where((item) => chosen.contains(item['name']))
          .map((item) =>
              {'vendor_id': vendor['id'], 'university_id': item['id']})
          .toList();
      if (selected.isEmpty) {
        throw const AuthException(
            'No active selected universities were found.');
      }
      await client.from('vendor_universities').upsert(
            selected,
            onConflict: 'vendor_id,university_id',
            ignoreDuplicates: true,
          );

      const documentTypes = {
        'icFront': 'ic_front',
        'icBack': 'ic_back',
        'selfie': 'selfie',
        'ssm': 'ssm',
        'kkm': 'kkm',
        'typhoid': 'typhoid',
        'kitchen': 'kitchen',
      };
      final documents = <Map<String, dynamic>>[];
      for (final entry in documentTypes.entries) {
        final images = uploads[entry.key] ?? [];
        for (var index = 0; index < images.length; index++) {
          final path =
              '${user.id}/${DateTime.now().microsecondsSinceEpoch}_${entry.key}_$index.jpg';
          await client.storage
              .from('vendor-documents')
              .uploadBinary(path, images[index]);
          documents.add({
            'vendor_id': vendor['id'],
            'document_type': entry.value,
            'file_url': path
          });
        }
      }
      if (documents.isNotEmpty) {
        await client.from('vendor_documents').insert(documents);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
            builder: (_) => const VendorApplicationPendingPage()),
      );
    } on AuthException catch (error) {
      debugPrint('Vendor signup AuthException: $error');
      if (mounted) {
        if (error.statusCode == '500' && error.code == 'unexpected_failure') {
          message(
              'Supabase could not save the new account. Apply the latest SQL migration in supabase/migrations, then retry.');
          return;
        }
        final details = [
          error.message,
          if (error.code != null) 'code: ${error.code}',
          if (error.statusCode != null) 'HTTP ${error.statusCode}',
        ];
        message(details.join(' · '));
      }
    } on PostgrestException catch (error) {
      if (mounted) message('Registration could not be saved: ${error.message}');
    } on StorageException catch (error) {
      if (mounted) {
        message('A registration file could not be uploaded: ${error.message}');
      }
    } catch (error) {
      debugPrint('Vendor registration failed: $error');
      if (mounted) message('Vendor registration failed: $error');
    } finally {
      if (mounted) setState(() => registering = false);
    }
  }

  Widget input(
    String label,
    String hint, {
    String? Function(String?)? validator,
    bool phone = false,
    bool secret = false,
    bool confirm = false,
    int lines = 1,
    int? maxLength,
  }) {
    final obscure = confirm ? confirmHidden : hidden;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        key: confirm ? confirmation : null,
        controller: secret && !confirm
            ? password
            : fields.putIfAbsent(label, TextEditingController.new),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        maxLines: lines,
        maxLength: maxLength,
        obscureText: secret && obscure,
        autocorrect: !secret,
        enableSuggestions: !secret,
        keyboardType: phone
            ? TextInputType.phone
            : label == 'Email Address'
                ? TextInputType.emailAddress
                : lines > 1
                    ? TextInputType.multiline
                    : TextInputType.text,
        inputFormatters: phone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ]
            : null,
        onChanged: (_) {
          if (confirm) confirmationEdited = true;
          if (secret && !confirm && confirmationEdited) {
            confirmation.currentState?.validate();
          }
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: lines > 1,
          errorMaxLines: 3,
          suffixIcon: secret
              ? IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() {
                    if (confirm) {
                      confirmHidden = !confirmHidden;
                    } else {
                      hidden = !hidden;
                    }
                  }),
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  String? requiredText(String? value, String label, int min) {
    final text = (value ?? '').trim();
    if (text.length < min ||
        !RegExp(r'[\p{L}]', unicode: true).hasMatch(text)) {
      return 'Enter a valid $label (at least $min characters).';
    }
    return null;
  }

  Future<void> pick(String id, bool multiple) async {
    if (picking != null) return;
    setState(() => picking = id);
    try {
      final picker = ImagePicker();
      final images = multiple
          ? await picker.pickMultiImage(
              maxWidth: 2000,
              maxHeight: 2000,
              imageQuality: 90,
              limit: 6,
            )
          : [
              if (await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 2000,
                maxHeight: 2000,
                imageQuality: 90,
              )
                  case final XFile file)
                file,
            ];
      if (images.isEmpty) return;
      final bytes = <Uint8List>[];
      for (final image in images) {
        if (await image.length() > 10 * 1024 * 1024) {
          throw const FormatException('Select images smaller than 10 MB.');
        }
        bytes.add(await image.readAsBytes());
      }
      if (!mounted) return;
      setState(() => uploads[id] = bytes);
      uploadFields[id]?.currentState?.didChange(bytes);
    } on FormatException catch (error) {
      if (mounted) message(error.message);
    } catch (_) {
      if (mounted) message('Could not select these photos. Please try again.');
    } finally {
      if (mounted) setState(() => picking = null);
    }
  }

  void reviewPhotos(String title, List<Uint8List> photos, int initialIndex) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF172019),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _PhotoGallery(
                  photos: List.of(photos),
                  initialIndex: initialIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget upload(
    String id,
    String title, {
    bool optional = false,
    bool multiple = false,
    bool logo = false,
  }) {
    final key = uploadFields.putIfAbsent(
      id,
      () => GlobalKey<FormFieldState<List<Uint8List>>>(),
    );
    return FormField<List<Uint8List>>(
      key: key,
      initialValue: uploads[id],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) => !optional && (value == null || value.isEmpty)
          ? 'Please add $title.'
          : null,
      builder: (state) {
        final photos = state.value ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: state.hasError
                    ? Theme.of(context).colorScheme.error
                    : const Color(0xFFDDDCD3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('upload-$id'),
              onTap: picking == null ? () => pick(id, multiple) : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                inherit: false,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF253729),
                                decoration: TextDecoration.none,
                              ),
                              children: [
                                TextSpan(text: title),
                                if (optional)
                                  const TextSpan(text: ' (optional)')
                                else if (!logo)
                                  const TextSpan(
                                    text: ' *',
                                    style: TextStyle(color: Color(0xFFBA1A1A)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (photos.isEmpty)
                          IconButton(
                            tooltip: 'Upload $title',
                            onPressed: picking == null
                                ? () => pick(id, multiple)
                                : null,
                            icon: picking == id
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.upload_outlined),
                          )
                        else
                          SizedBox(
                            width: photos.length == 1 ? 56 : 112,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var index = 0;
                                    index < photos.length;
                                    index++)
                                  SizedBox(
                                    width: 52,
                                    height: 56,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 0,
                                          bottom: 0,
                                          child: Tooltip(
                                            message:
                                                'Review $title photo ${index + 1}',
                                            child: InkWell(
                                              onTap: () => reviewPhotos(
                                                title,
                                                photos,
                                                index,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.memory(
                                                  photos[index],
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    _,
                                                    error,
                                                    stack,
                                                  ) =>
                                                      const SizedBox(
                                                    width: 48,
                                                    height: 48,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: IconButton.filled(
                                              tooltip:
                                                  'Remove $title photo ${index + 1}',
                                              padding: EdgeInsets.zero,
                                              iconSize: 14,
                                              style: IconButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF253729,
                                                ),
                                                foregroundColor: Colors.white,
                                              ),
                                              onPressed: picking == null
                                                  ? () {
                                                      final remaining =
                                                          List<Uint8List>.of(
                                                        photos,
                                                      )..removeAt(index);
                                                      setState(
                                                        () => uploads[id] =
                                                            remaining,
                                                      );
                                                      state.didChange(
                                                        remaining,
                                                      );
                                                    }
                                                  : null,
                                              icon: const Icon(Icons.close),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (state.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          state.errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget universitySelector() => FormField<Set<String>>(
        key: universityField,
        initialValue: <String>{},
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) => value == null || value.isEmpty
            ? 'Select at least one university.'
            : null,
        builder: (state) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final selected = Set<String>.of(state.value ?? {});
                  final result = await showDialog<Set<String>>(
                    context: context,
                    builder: (context) => StatefulBuilder(
                      builder: (context, update) => AlertDialog(
                        title: const Text('Universities Served'),
                        content: SizedBox(
                          width: 380,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: universities
                                  .map(
                                    (name) => CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(name),
                                      value: selected.contains(name),
                                      onChanged: (checked) => update(() {
                                        if (checked == true) {
                                          selected.add(name);
                                        } else {
                                          selected.remove(name);
                                        }
                                      }),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, selected),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (result != null && mounted) state.didChange(result);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Universities Served',
                    errorText: state.errorText,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    state.value!.isEmpty
                        ? 'Select universities'
                        : '${state.value!.length} selected',
                  ),
                ),
              ),
              if (state.value!.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: state.value!
                      .map(
                        (name) => InputChip(
                          label:
                              Text(name, style: const TextStyle(fontSize: 11)),
                          onDeleted: () =>
                              state.didChange({...state.value!}..remove(name)),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: step == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && step > 0) moveTo(step - 1);
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFFCF5),
            title: const Text('Vendor registration'),
            leading: IconButton(
              tooltip: step == 0 ? 'Back to sign in' : 'Previous step',
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (step > 0) {
                  moveTo(step - 1);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  controller: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'STEP ${step + 1} OF 3',
                        style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF728053),
                        ),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (step + 1) / 3,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF344B35),
                        backgroundColor: const Color(0xFFECEEE3),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        titles[step],
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF253729),
                        ),
                      ),
                      const SizedBox(height: 24),
                      IndexedStack(
                        index: step,
                        sizing: StackFit.loose,
                        children: [
                          for (var index = 0; index < 3; index++)
                            Visibility(
                              visible: step == index,
                              maintainState: true,
                              child: Form(
                                key: forms[index],
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: index == 0
                                      ? [
                                          input(
                                            'Full Name',
                                            'Enter your full name',
                                            validator: (value) => requiredText(
                                              value,
                                              'full name',
                                              2,
                                            ),
                                          ),
                                          input(
                                            'Username',
                                            'Choose a username',
                                            validator:
                                                RegistrationValidators.username,
                                          ),
                                          input(
                                            'Email Address',
                                            'you@example.com',
                                            validator:
                                                RegistrationValidators.email,
                                          ),
                                          input(
                                            'Phone Number',
                                            '0123456789',
                                            phone: true,
                                            validator:
                                                RegistrationValidators.phone,
                                          ),
                                          input(
                                            'Password',
                                            'At least 8 characters, letters and numbers',
                                            secret: true,
                                            validator:
                                                RegistrationValidators.password,
                                          ),
                                          input(
                                            'Confirm Password',
                                            'Re-enter your password',
                                            secret: true,
                                            confirm: true,
                                            validator: (value) =>
                                                RegistrationValidators
                                                    .confirmation(
                                              value,
                                              password.text,
                                            ),
                                          ),
                                        ]
                                      : index == 1
                                          ? [
                                              upload(
                                                'logo',
                                                'Business Logo',
                                                logo: true,
                                              ),
                                              input(
                                                'Business Name',
                                                'Enter your business name',
                                                maxLength: 100,
                                                validator: (value) =>
                                                    requiredText(
                                                  value,
                                                  'business name',
                                                  2,
                                                ),
                                              ),
                                              input(
                                                'Business Description',
                                                'Tell customers about your kitchen and food',
                                                lines: 4,
                                                maxLength: 1000,
                                                validator: (value) =>
                                                    requiredText(
                                                  value,
                                                  'business description',
                                                  20,
                                                ),
                                              ),
                                              input(
                                                'Business Contact Number',
                                                '0123456789',
                                                phone: true,
                                                validator:
                                                    RegistrationValidators
                                                        .phone,
                                              ),
                                              input(
                                                'Business Address',
                                                'Unit, street, city, postcode and state',
                                                lines: 3,
                                                maxLength: 500,
                                                validator: (value) =>
                                                    requiredText(
                                                  value,
                                                  'business address',
                                                  10,
                                                ),
                                              ),
                                              universitySelector(),
                                            ]
                                          : [
                                              upload('icFront',
                                                  'IC Photo — Front'),
                                              upload(
                                                  'icBack', 'IC Photo — Back'),
                                              upload(
                                                  'selfie', 'Selfie with IC'),
                                              upload(
                                                'ssm',
                                                'SSM Business Registration Certificate',
                                                optional: true,
                                              ),
                                              upload(
                                                'kkm',
                                                'KKM Food Premises Registration',
                                                optional: true,
                                              ),
                                              upload(
                                                'typhoid',
                                                'Typhoid Vaccination Evidence',
                                              ),
                                              upload(
                                                'kitchen',
                                                'Food Preparation Area Photos',
                                                multiple: true,
                                              ),
                                              FormField<bool>(
                                                initialValue: false,
                                                validator: (value) => value ==
                                                        true
                                                    ? null
                                                    : 'Please accept the agreement to continue.',
                                                builder: (state) => Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    CheckboxListTile(
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      controlAffinity:
                                                          ListTileControlAffinity
                                                              .leading,
                                                      value: state.value,
                                                      onChanged: (value) {
                                                        agreed = value ?? false;
                                                        state.didChange(agreed);
                                                      },
                                                      title: const Text(
                                                        'I agree to the Terms of Service and Privacy Policy.',
                                                        style: TextStyle(
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                    if (state.hasError)
                                                      Text(
                                                        state.errorText!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .error,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                            picking == null && !registering ? next : null,
                        child: Text(
                          registering
                              ? 'Creating account…'
                              : step == 2
                                  ? 'Register'
                                  : 'Continue',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _PhotoGallery extends StatefulWidget {
  const _PhotoGallery({required this.photos, required this.initialIndex});
  final List<Uint8List> photos;
  final int initialIndex;
  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  late final PageController pages;
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    pages = PageController(initialPage: index);
  }

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: pages,
              itemCount: widget.photos.length,
              onPageChanged: (value) => setState(() => index = value),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    widget.photos[index],
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stack) => const Text(
                      'Unable to display this photo.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous photo',
                  onPressed: index > 0
                      ? () => pages.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  color: Colors.white,
                  disabledColor: Colors.white30,
                ),
                Text(
                  '${index + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  tooltip: 'Next photo',
                  onPressed: index < widget.photos.length - 1
                      ? () => pages.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          )
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  color: Colors.white,
                  disabledColor: Colors.white30,
                ),
              ],
            ),
          ),
        ],
      );
}
