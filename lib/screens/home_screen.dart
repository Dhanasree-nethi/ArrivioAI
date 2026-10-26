import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/arrivio_logo.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onStartJourney,
    required this.onOpenProfile,
    this.userName,
  });

  final VoidCallback onStartJourney;
  final VoidCallback onOpenProfile;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = MediaQuery.sizeOf(context).width >= 600
        ? 32.0
        : 20.0;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        children: [
          Row(
            children: [
              const Expanded(child: ArrivioLogo()),
              IconButton.filledTonal(
                onPressed: () {},
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Open profile',
                child: InkWell(
                  key: const Key('profile_button'),
                  onTap: onOpenProfile,
                  borderRadius: BorderRadius.circular(22),
                  child: Ink(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF0FF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: const TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'Good morning, $_greetingName',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 7),
          const Text(
            'Travel with confidence. We will help you arrive on time.',
          ),
          const SizedBox(height: 26),
          _StartJourneyCard(onStart: onStartJourney),
          const SizedBox(height: 30),
          const SectionHeader(title: 'My destination'),
          const SizedBox(height: 12),
          _OutlinedInfoCard(
            icon: Icons.location_searching_rounded,
            title: 'No destination selected',
            detail: 'Choose a destination to prepare your arrival alerts.',
            action: TextButton.icon(
              onPressed: onStartJourney,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add destination'),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Live journey'),
          const SizedBox(height: 12),
          _OutlinedInfoCard(
            icon: Icons.gps_off_rounded,
            title: 'Tracking is not active',
            detail: 'Live location will appear here when you start a journey.',
            iconBackground: const Color(0xFFF3F4F6),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Recent journeys', actionLabel: 'See all'),
          const SizedBox(height: 12),
          _RecentJourneyCard(onStart: onStartJourney),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Settings'),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: const [
                _SettingsRow(
                  icon: Icons.notifications_outlined,
                  title: 'Arrival alerts',
                  detail: 'Not configured',
                ),
                Divider(height: 1, indent: 66),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Location privacy',
                  detail: 'You are in control',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _greetingName {
    final name = userName?.trim();
    return name == null || name.isEmpty ? 'there' : name;
  }

  String get _initials {
    final parts = _greetingName.split(RegExp(r'\s+'));
    return parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
  }
}

class _StartJourneyCard extends StatelessWidget {
  const _StartJourneyCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F14213D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.near_me_rounded, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Where are you headed?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set a destination and get timely alerts before your stop.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.navy,
              ),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Start journey'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedInfoCard extends StatelessWidget {
  const _OutlinedInfoCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
    this.iconBackground = const Color(0xFFEAF0FF),
  });
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;
  final Color iconBackground;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(detail, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ...(action == null ? const <Widget>[] : [action!]),
        ],
      ),
    ),
  );
}

class _RecentJourneyCard extends StatelessWidget {
  const _RecentJourneyCard({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: AppTheme.mutedInk),
              const SizedBox(width: 10),
              Text(
                'No journeys yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Your completed trips will be securely listed here.'),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onStart,
            child: const Text('Start your first journey'),
          ),
        ],
      ),
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String title;
  final String detail;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppTheme.mutedInk),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text(detail),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}
