import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding_flow.dart';
import 'services/active_journey_repository.dart';
import 'services/arrival_alert_service.dart';
import 'services/onboarding_repository.dart';
import 'services/journey_history_repository.dart';
import 'services/location_service.dart';
import 'services/map_tiler_config.dart';
import 'services/place_search_service.dart';
import 'services/route_service.dart';
import 'theme/app_theme.dart';
import 'widgets/arrivio_brand.dart';

void main() {
  MapTilerConfig.logDebugConfiguration();
  runApp(const ArrivioApp());
}

class ArrivioApp extends StatefulWidget {
  const ArrivioApp({
    super.key,
    this.onboardingRepository,
    this.resetOnboardingOnLaunch = false,
    this.locationService,
    this.placeSearchService,
    this.routeService,
    this.journeyHistoryRepository,
    this.activeJourneyRepository,
    this.arrivalAlertNotifier,
  });

  final OnboardingRepository? onboardingRepository;
  final bool resetOnboardingOnLaunch;
  final LocationService? locationService;
  final PlaceSearchService? placeSearchService;
  final RouteService? routeService;
  final JourneyHistoryRepository? journeyHistoryRepository;
  final ActiveJourneyRepository? activeJourneyRepository;
  final ArrivalAlertNotifier? arrivalAlertNotifier;

  @override
  State<ArrivioApp> createState() => _ArrivioAppState();
}

class _ArrivioAppState extends State<ArrivioApp> {
  late final OnboardingRepository _repository =
      widget.onboardingRepository ?? SharedPreferencesOnboardingRepository();
  static const _resetForDevelopment = bool.fromEnvironment(
    'ARRIVIO_RESET_ONBOARDING',
  );

  late Future<_StartupState> _startupState = _loadStartupState();

  Future<_StartupState> _loadStartupState() async {
    if (widget.resetOnboardingOnLaunch || _resetForDevelopment) {
      await _repository.resetOnboarding();
    }
    final completed = await _repository.hasCompletedOnboarding();
    final profile = completed ? await _repository.getProfile() : null;
    return _StartupState(completed: completed, profile: profile);
  }

  void _finishOnboarding(OnboardingProfile profile) {
    setState(() {
      _startupState = Future<_StartupState>.value(
        _StartupState(completed: true, profile: profile),
      );
    });
  }

  Future<void> _updateProfile(OnboardingProfile profile) async {
    await _repository.updateProfile(profile);
    if (!mounted) return;
    setState(() {
      _startupState = Future<_StartupState>.value(
        _StartupState(completed: true, profile: profile),
      );
    });
  }

  Future<void> _signOut() async {
    await _repository.resetOnboarding();
    if (!mounted) return;
    setState(() {
      _startupState = Future<_StartupState>.value(
        const _StartupState(completed: false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ArrivioAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<_StartupState>(
        future: _startupState,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _BrandSplash();
          return snapshot.data!.completed
              ? AppShell(
                  profile: snapshot.data!.profile,
                  locationService: widget.locationService,
                  placeSearchService: widget.placeSearchService,
                  routeService: widget.routeService,
                  journeyHistoryRepository: widget.journeyHistoryRepository,
                  activeJourneyRepository: widget.activeJourneyRepository,
                  arrivalAlertNotifier: widget.arrivalAlertNotifier,
                  onProfileUpdated: _updateProfile,
                  onSignOut: _signOut,
                )
              : OnboardingFlow(
                  repository: _repository,
                  onComplete: _finishOnboarding,
                );
        },
      ),
    );
  }
}

class _StartupState {
  const _StartupState({required this.completed, this.profile});

  final bool completed;
  final OnboardingProfile? profile;
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: ArrivioBrand(lockupSize: BrandLockupSize.large)),
    );
  }
}
