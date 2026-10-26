import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/arrivio_brand.dart';

class LocationExplanationScreen extends StatelessWidget {
  const LocationExplanationScreen({
    super.key,
    required this.name,
    required this.isSaving,
    required this.onBack,
    required this.onComplete,
  });
  final String name;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onComplete;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: isSaving ? null : onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                  const ArrivioMark(size: 32),
                ],
              ),
              const SizedBox(height: 52),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  color: Color(0xFF167A52),
                  size: 34,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Location, on your terms',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Hi $name, ArrivioAI only uses your location while an active journey needs it.',
              ),
              const SizedBox(height: 24),
              const _Benefit(
                icon: Icons.route_outlined,
                text: 'Track journey progress and monitor your position.',
              ),
              const _Benefit(
                icon: Icons.notifications_active_outlined,
                text: 'Know when you are approaching your stop.',
              ),
              const _Benefit(
                icon: Icons.verified_outlined,
                text: 'Receive a clear alert when you have arrived.',
              ),
              const SizedBox(height: 20),
              const Text(
                'We will ask for permission when you start a live journey. You can change this anytime in your device settings.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.mutedInk,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onComplete,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Finish setup'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppTheme.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text),
          ),
        ),
      ],
    ),
  );
}
