import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/arrivio_brand.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onContinue});
  final ValueChanged<String> onContinue;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    final value = _controller.text.trim();
    if (value.isEmpty ||
        !(value.contains('@') ||
            RegExp(r'^\+?[0-9][0-9\s-]{7,}$').hasMatch(value))) {
      setState(() => _error = 'Enter a valid email address or phone number.');
      return;
    }
    widget.onContinue(value);
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
                const Spacer(flex: 2),
                const ArrivioBrand(lockupSize: BrandLockupSize.large),
                const SizedBox(height: 42),
                Text(
                  'Welcome to ArrivioAI',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Travel with confidence. ArrivioAI helps you stay aware of your destination, so you do not miss your stop.',
                ),
                const SizedBox(height: 32),
                Text(
                  'Email or phone number',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 9),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _continue(),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    errorText: _error,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFDDE3EC)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This is a local onboarding preview. Sign-in will connect to a secure account service later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
