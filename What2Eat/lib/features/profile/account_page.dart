import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'edit_profile_page.dart';
import 'profile_repository.dart';
import 'profile_widgets.dart';
import 'user_profile.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.repository, this.onUpdated});
  final ProfileRepository? repository;
  final ValueChanged<UserProfile>? onUpdated;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final ProfileRepository _repository;
  UserProfile? _profile;
  String? _error, _campusName;
  bool _loading = true;
  int _avatarRevision = 0;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        SupabaseProfileRepository(Supabase.instance.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _repository.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _avatarRevision++;
      });
      widget.onUpdated?.call(profile);
      await _loadCampus(profile);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ProfileFailure ? error.message : 'Could not load your profile. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCampus(UserProfile profile) async {
    String? name;
    if (profile.isStudent && profile.universityId != null) {
      try {
        final choices = await _repository.universities();
        for (final choice in choices) {
          if (choice.id == profile.universityId) name = choice.name;
        }
      } catch (_) {
        /* Profile details still load if the directory is offline. */
      }
      name ??= 'Current university (directory unavailable)';
    } else if (profile.isVendor && profile.servedUniversityIds.isNotEmpty) {
      try {
        // Directory order, so "Other university" is listed last.
        final choices = await _repository.universities();
        final served = profile.servedUniversityIds.toSet();
        final names = [
          for (final c in choices)
            if (served.contains(c.id)) c.name,
        ];
        final unavailable =
            served.length - choices.where((c) => served.contains(c.id)).length;
        name = [
          ...names,
          for (var i = 0; i < unavailable; i++) 'Unavailable university',
        ].join('\n');
      } catch (_) {
        name =
            '${profile.servedUniversityIds.length} universities (directory unavailable)';
      }
    }
    if (mounted) setState(() => _campusName = name);
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfilePage(profile: _profile!, repository: _repository),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _profile = updated;
      _avatarRevision++;
    });
    widget.onUpdated?.call(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your profile has been updated.')),
    );
    await _loadCampus(updated);
  }

  Widget _detail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 3),
              Text(
                value.isEmpty ? 'Not added' : value,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => profileTheme(
    context,
    (context) => Scaffold(
      appBar: AppBar(
        title: const Text('My account'),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _profile == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    children: [
                      if (_loading) const LinearProgressIndicator(),
                      Center(
                        child: ProfileAvatar(
                          key: ValueKey(_avatarRevision),
                          repository: _repository,
                          reference: _profile!.avatarPath,
                          size: 116,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!.displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '@${_profile!.username}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Center(
                        child: Chip(
                          label: Text(_profile!.roleLabel),
                          avatar: const Icon(Icons.badge_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _edit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit profile'),
                      ),
                      const SizedBox(height: 24),
                      ProfileSection(
                        title: 'Account details',
                        children: [
                          _detail(
                            context,
                            Icons.person_outline,
                            'Full name',
                            _profile!.fullName,
                          ),
                          _detail(
                            context,
                            Icons.alternate_email,
                            'Username',
                            _profile!.username,
                          ),
                          _detail(
                            context,
                            Icons.mail_outline,
                            'Sign-in email',
                            _profile!.email,
                          ),
                          _detail(
                            context,
                            Icons.phone_outlined,
                            'Phone number',
                            _profile!.phone,
                          ),
                          if (_profile!.isStudent)
                            _detail(
                              context,
                              Icons.school_outlined,
                              'University',
                              _campusName ?? 'Not selected',
                            ),
                          if (_profile!.isVendor)
                            _detail(
                              context,
                              Icons.school_outlined,
                              'Universities served',
                              _campusName ?? '',
                            ),
                        ],
                      ),
                      Center(
                        child: Text(
                          'Your details. Your campus connection.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
