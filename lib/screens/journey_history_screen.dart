import 'package:flutter/material.dart';

import '../models/journey_history_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/arrivio_logo.dart';

class JourneyHistoryScreen extends StatelessWidget {
  const JourneyHistoryScreen({
    super.key,
    required this.journeys,
    this.isLoading = false,
    this.loadError,
  });

  final List<JourneyHistoryEntry> journeys;
  final bool isLoading;
  final String? loadError;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ArrivioLogo(),
          const SizedBox(height: 24),
          Text('Journey history', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(child: _content(context)),
        ],
      ),
    ),
  );

  Widget _content(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (loadError != null) {
      return Center(
        child: Text(loadError!, textAlign: TextAlign.center),
      );
    }
    if (journeys.isEmpty) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route_outlined, color: AppTheme.blue, size: 36),
                const SizedBox(height: 14),
                Text(
                  'No journeys yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Finished and cancelled journeys will appear here.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('journey_history_list'),
      itemCount: journeys.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _JourneyHistoryCard(
        journey: journeys[index],
      ),
    );
  }
}

class _JourneyHistoryCard extends StatelessWidget {
  const _JourneyHistoryCard({required this.journey});

  final JourneyHistoryEntry journey;

  @override
  Widget build(BuildContext context) {
    final isCompleted = journey.status == JourneyHistoryStatus.completed;
    final statusColor = isCompleted
        ? const Color(0xFF067647)
        : const Color(0xFFB42318);
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    journey.destination,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Cancelled',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Started: ${_formatDateTime(localizations, journey.startedAt)}',
            ),
            const SizedBox(height: 4),
            Text('Ended: ${_formatDateTime(localizations, journey.endedAt)}'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(MaterialLocalizations localizations, DateTime value) {
    final local = value.toLocal();
    return '${localizations.formatMediumDate(local)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}
