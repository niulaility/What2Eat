import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../authentication/registration_validators.dart';
import 'profile_repository.dart';
import 'profile_validation.dart';
import 'profile_widgets.dart';
import 'user_profile.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.profile,
    required this.repository,
    this.pickImage,
  });
  final UserProfile profile;
  final ProfileRepository repository;
  final Future<XFile?> Function()? pickImage;
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _username, _phone;
  late String _campus;
  List<UniversityChoice> _universities = [];
  bool _loadingUniversities = false, _universityError = false;
  bool _saving = false,
      _picking = false,
      _removePhoto = false,
      _allowPop = false,
      _confirmingExit = false;
  ProfileImage? _photo;
  String? _uploadedDraftPath, _error;
  bool get _busy => _saving || _picking;
  bool get _dirty =>
      _name.text.trim() != widget.profile.fullName.trim() ||
      _username.text.trim() != widget.profile.username ||
      ProfileValidation.normalizePhone(_phone.text) !=
          ProfileValidation.normalizePhone(widget.profile.phone) ||
      (widget.profile.isStudent &&
          _campus != (widget.profile.universityId ?? '')) ||
      _photo != null ||
      _removePhoto;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.fullName)
      ..addListener(_changed);
    _username = TextEditingController(text: widget.profile.username)
      ..addListener(_changed);
    _phone = TextEditingController(text: widget.profile.phone)
      ..addListener(_changed);
    _campus = widget.profile.universityId ?? '';
    if (widget.profile.isStudent) _loadUniversities();
    if (widget.pickImage == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadUniversities() async {
    setState(() {
      _loadingUniversities = true;
      _universityError = false;
    });
    try {
      final choices = await widget.repository.universities();
      if (mounted) setState(() => _universities = choices);
    } catch (_) {
      if (mounted) setState(() => _universityError = true);
    } finally {
      if (mounted) setState(() => _loadingUniversities = false);
    }
  }

  Future<void> _recoverPhoto() async {
    try {
      final response = await ImagePicker().retrieveLostData();
      if (!mounted || response.isEmpty) return;
      if (response.files?.isNotEmpty == true) {
        await _previewPhoto(response.files!.first);
      } else if (response.exception != null) {
        _showError(
          'Could not restore the photo selection. Please choose it again.',
        );
      }
    } catch (_) {
      // Lost-data recovery is optional; a fresh gallery selection still works.
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _choosePhoto() async {
    if (_busy) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Your profile photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('A personal photo for your What2Eat account.'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
              if (_photo != null ||
                  (widget.profile.avatarPath != null && !_removePhoto))
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Remove photo'),
                  onTap: () => Navigator.pop(context, 'remove'),
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      setState(() {
        _photo = null;
        _uploadedDraftPath = null;
        _removePhoto = widget.profile.avatarPath != null;
        _error = null;
      });
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image =
          await (widget.pickImage?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 1600,
                maxHeight: 1600,
                imageQuality: 90,
                requestFullMetadata: false,
              ));
      if (image != null && mounted) await _previewPhoto(image);
    } catch (error) {
      _showError(
        error is ProfileFailure
            ? error.message
            : 'Could not open the photo picker. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _previewPhoto(XFile image) async {
    final candidate = await ProfileValidation.readImage(image);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preview profile photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.memory(
                candidate.bytes,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your photo will change when you save your profile.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use photo'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _photo = candidate;
        _uploadedDraftPath = null;
        _removePhoto = false;
        _error = null;
      });
    }
  }

  void _leave([UserProfile? result]) {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _requestLeave() async {
    if (_busy || _confirmingExit) return;
    if (!_dirty) {
      _leave();
      return;
    }
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes have not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (discard == true && mounted) _leave();
  }

  Future<void> _save() async {
    if (_busy || !_dirty || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_photo != null && _uploadedDraftPath == null) {
        _uploadedDraftPath = await widget.repository.uploadAvatar(_photo!);
      }
      final updated = await widget.repository.save(
        ProfileChanges(
          userId: widget.profile.id,
          fullName: _name.text.trim(),
          username: _username.text.trim(),
          phone: ProfileValidation.normalizePhone(_phone.text),
          expectedUpdatedAt: widget.profile.updatedAt,
          universityId: widget.profile.isStudent
              ? (_campus.isEmpty ? null : _campus)
              : widget.profile.universityId,
          avatarPath: _removePhoto
              ? null
              : (_uploadedDraftPath ?? widget.profile.avatarPath),
        ),
      );
      if (mounted) _leave(updated);
    } catch (error) {
      _showError(
        error is ProfileFailure ? error.message : 'Could not save your profile. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => profileTheme(context, (context) {
    final colors = Theme.of(context).colorScheme;
    final choices = [
      const UniversityChoice('', 'Other / not listed', 'OTHER'),
      ..._universities,
    ];
    if (_campus.isNotEmpty && !choices.any((u) => u.id == _campus)) {
      choices.add(
        UniversityChoice(_campus, 'Current university (unavailable)'),
      );
    }
    return PopScope<UserProfile>(
      canPop: _allowPop || (!_dirty && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          leading: BackButton(onPressed: _busy ? null : _requestLeave),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                child: ListView(
                  key: const ValueKey('profile-form'),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Edit profile photo',
                        child: InkWell(
                          onTap: _busy ? null : _choosePhoto,
                          customBorder: const CircleBorder(),
                          child: Stack(
                            children: [
                              ProfileAvatar(
                                repository: widget.repository,
                                reference: widget.profile.avatarPath,
                                preview: _photo?.bytes,
                                removed: _removePhoto,
                                size: 120,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD85C),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surface,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    color: Color(0xFF253729),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _choosePhoto,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(_picking ? 'Opening photo…' : 'Edit photo'),
                    ),
                    Center(
                      child: Text(
                        'JPEG or PNG · Up to 5 MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ProfileSection(
                      title: 'Personal information',
                      subtitle:
                          'The details your campus community knows you by.',
                      children: [
                        TextFormField(
                          key: const ValueKey('profile-name'),
                          controller: _name,
                          enabled: !_busy,
                          maxLength: 100,
                          validator: ProfileValidation.name,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const ValueKey('profile-username'),
                          controller: _username,
                          enabled: !_busy,
                          maxLength: 30,
                          validator: RegistrationValidators.username,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixIcon: Icon(Icons.alternate_email),
                            counterText: '',
                            helperText: '3–30 letters, numbers or underscores.',
                          ),
                        ),
                      ],
                    ),
                    ProfileSection(
                      title: 'Contact details',
                      children: [
                        TextFormField(
                          initialValue: widget.profile.email,
                          readOnly: true,
                          enableInteractiveSelection: true,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline),
                            suffixIcon: Icon(Icons.lock_outline, size: 18),
                            helperText: 'Your verified sign-in email. Email cannot be edited here.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          key: const ValueKey('profile-phone'),
                          controller: _phone,
                          enabled: !_busy,
                          validator: ProfileValidation.phone,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: 'e.g. +60123456789',
                            helperText: 'Optional · Include your country code if needed.',
                          ),
                        ),
                      ],
                    ),
                    if (widget.profile.isStudent)
                      ProfileSection(
                        title: 'Your campus',
                        subtitle:
                            'Choose from the Malaysian university directory.',
                        children: [
                          if (_loadingUniversities)
                            const LinearProgressIndicator(),
                          if (_universityError) ...[
                            const Text(
                              'Could not load the university directory. Your current selection is kept.',
                            ),
                            TextButton.icon(
                              onPressed: _busy ? null : _loadUniversities,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry universities'),
                            ),
                          ] else
                            DropdownButtonFormField<String>(
                              key: ValueKey(
                                'campus-$_campus-${choices.length}',
                              ),
                              initialValue: _campus,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'University',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              items: choices
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u.id,
                                      child: Row(
                                        children: [
                                          if (u.code.isNotEmpty) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3EFE2),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                u.code.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF253729),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                          ],
                                          Expanded(
                                            child: Text(
                                              u.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _busy || _loadingUniversities
                                  ? null
                                  : (value) =>
                                        setState(() => _campus = value ?? ''),
                            ),
                        ],
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(color: colors.error),
                          ),
                        ),
                      ),
                    FilledButton(
                      key: const ValueKey('save-profile'),
                      onPressed: _busy || !_dirty ? null : _save,
                      child: _saving
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Saving…'),
                              ],
                            )
                          : const Text('Save changes'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _requestLeave,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
}
