import 'package:flutter/material.dart';

import '../models/destination.dart';
import '../theme/app_theme.dart';

class ArrivalAlertScreen extends StatelessWidget {
  const ArrivalAlertScreen({
    super.key,
    required this.destination,
    required this.isReached,
    required this.onClose,
    required this.onShowReached,
  });

  final Destination destination;
  final bool isReached;
  final VoidCallback onClose;
  final VoidCallback onShowReached;

  @override
  Widget build(BuildContext context) {
    final Color accent = isReached
        ? const Color(0xFF167A52)
        : const Color(0xFFC56800);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Back to journey',
                ),
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isReached
                        ? Icons.check_circle_rounded
                        : Icons.notifications_active_rounded,
                    color: accent,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text(
                  isReached ? 'You have arrived' : 'Your stop is coming up',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  isReached
                      ? 'You have reached your selected destination.'
                      : 'Stay ready — you are approaching your selected destination.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              _DestinationSummary(destination: destination, accent: accent),
              const SizedBox(height: 14),
              const Text(
                'Preview state — live alerts will be connected to location and notification services later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
              ),
              const Spacer(),
              if (!isReached)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onShowReached,
                    child: const Text('Preview destination reached'),
                  ),
                ),
              if (!isReached) const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onClose,
                  child: const Text('Back to journey'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationSummary extends StatelessWidget {
  const _DestinationSummary({required this.destination, required this.accent});

  final Destination destination;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_on_rounded, color: accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Destination',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    destination.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(destination.address),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
