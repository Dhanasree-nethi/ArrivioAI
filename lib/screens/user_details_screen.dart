import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/arrivio_brand.dart';

class UserDetailsScreen extends StatefulWidget {
  const UserDetailsScreen({
    super.key,
    required this.initialContact,
    required this.onBack,
    required this.onContinue,
  });
  final String initialContact;
  final VoidCallback onBack;
  final ValueChanged<String> onContinue;
  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late final _contactController = TextEditingController(
    text: widget.initialContact,
  );
  final _nameController = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _contactController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter the name you would like us to use.');
      return;
    }
    widget.onContinue(name);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    const Spacer(),
                    const ArrivioMark(size: 32),
                  ],
                ),
                const Spacer(),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEAF0FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 39,
                          color: AppTheme.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Profile photo (optional)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.mutedInk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'A few details about you',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 9),
                const Text(
                  'This helps us make your journey experience feel more personal.',
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: 'Full name',
                    hintText: 'Alex Morgan',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _contactController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email or phone',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
