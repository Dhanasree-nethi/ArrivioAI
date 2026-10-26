import 'package:flutter/material.dart';

import '../services/onboarding_repository.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onBack,
    required this.onSave,
    required this.onSignOut,
  });

  final OnboardingProfile? profile;
  final VoidCallback onBack;
  final Future<void> Function(OnboardingProfile profile) onSave;
  final Future<void> Function() onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  bool _saving = false;

  String get _name => widget.profile?.fullName.trim().isNotEmpty == true
      ? widget.profile!.fullName.trim()
      : 'there';
  String get _contact => widget.profile?.contact ?? 'Not provided';
  String get _initials => _name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return _editing
        ? _EditProfileScreen(
            profile: widget.profile,
            isSaving: _saving,
            onBack: () => setState(() => _editing = false),
            onSave: (profile) async {
              setState(() => _saving = true);
              try {
                await widget.onSave(profile);
              } catch (_) {
                if (!mounted) return;
                setState(() => _saving = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'We could not save your profile. Please try again.',
                    ),
                  ),
                );
              }
            },
          )
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            tooltip: 'Back',
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFEAF0FF),
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: AppTheme.navy,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(_contact, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.edit_outlined),
                              title: const Text('Edit profile'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => setState(() => _editing = true),
                            ),
                            const Divider(height: 1, indent: 56),
                            const ListTile(
                              leading: Icon(Icons.notifications_outlined),
                              title: Text('Notification settings'),
                              subtitle: Text('Manage arrival alerts'),
                              trailing: Icon(Icons.chevron_right_rounded),
                            ),
                            const Divider(height: 1, indent: 56),
                            const ListTile(
                              leading: Icon(Icons.location_on_outlined),
                              title: Text('Location permission'),
                              subtitle: Text('Managed in device settings'),
                              trailing: Icon(Icons.chevron_right_rounded),
                            ),
                            const Divider(height: 1, indent: 56),
                            const ListTile(
                              leading: Icon(Icons.info_outline_rounded),
                              title: Text('About ArrivioAI'),
                              trailing: Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () async => widget.onSignOut(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen({
    required this.profile,
    required this.isSaving,
    required this.onBack,
    required this.onSave,
  });
  final OnboardingProfile? profile;
  final bool isSaving;
  final VoidCallback onBack;
  final ValueChanged<OnboardingProfile> onSave;
  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  late final _name = TextEditingController(text: widget.profile?.fullName);
  late final _contact = TextEditingController(text: widget.profile?.contact);
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final contact = _contact.text.trim();
    if (name.length < 2 || contact.isEmpty) {
      setState(() => _error = 'Enter your name and email or phone number.');
      return;
    }
    widget.onSave(OnboardingProfile(fullName: name, contact: contact));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.isSaving ? null : widget.onBack,
                      tooltip: 'Back to profile',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Full name',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contact,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email or phone',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.isSaving ? null : _save,
                    child: widget.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save changes'),
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
