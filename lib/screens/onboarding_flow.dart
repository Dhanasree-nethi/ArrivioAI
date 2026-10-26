import 'package:flutter/material.dart';

import '../services/onboarding_repository.dart';
import 'location_explanation_screen.dart';
import 'user_details_screen.dart';
import 'welcome_screen.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.repository,
    required this.onComplete,
  });
  final OnboardingRepository repository;
  final ValueChanged<OnboardingProfile> onComplete;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  String _contact = '';
  String _name = '';
  bool _saving = false;
  void _nextFromWelcome(String contact) => setState(() {
    _contact = contact;
    _step = 1;
  });
  void _nextFromDetails(String name) => setState(() {
    _name = name;
    _step = 2;
  });
  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      final profile = OnboardingProfile(fullName: _name, contact: _contact);
      await widget.repository.markOnboardingComplete(profile);
      if (mounted) widget.onComplete(profile);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not save your setup. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 260),
    child: switch (_step) {
      0 => WelcomeScreen(
        key: const ValueKey('welcome'),
        onContinue: _nextFromWelcome,
      ),
      1 => UserDetailsScreen(
        key: const ValueKey('details'),
        initialContact: _contact,
        onBack: () => setState(() => _step = 0),
        onContinue: _nextFromDetails,
      ),
      _ => LocationExplanationScreen(
        key: const ValueKey('location'),
        name: _name,
        isSaving: _saving,
        onBack: () => setState(() => _step = 1),
        onComplete: _complete,
      ),
    },
  );
}
