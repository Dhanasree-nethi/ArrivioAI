import 'package:flutter/material.dart';

import '../models/active_journey.dart';
import '../models/destination.dart';
import '../models/current_location.dart';
import '../models/journey_history_entry.dart';
import '../models/route.dart';
import '../services/active_journey_repository.dart';
import '../services/arrival_alert_service.dart';
import '../services/journey_history_repository.dart';
import '../services/location_service.dart';
import '../services/map_tiler_config.dart';
import '../services/onboarding_repository.dart';
import '../services/place_search_service.dart';
import '../services/route_service.dart';
import 'arrival_alert_screen.dart';
import 'destination_screen.dart';
import 'home_screen.dart';
import 'live_journey_screen.dart';
import 'journey_history_screen.dart';
import 'placeholder_screen.dart';
import 'profile_screen.dart';

enum _JourneyFlow {
  none,
  destination,
  liveJourney,
  approachingPreview,
  arrivalPreview,
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.profile,
    this.locationService,
    this.placeSearchService,
    this.routeService,
    this.journeyHistoryRepository,
    this.activeJourneyRepository,
    this.arrivalAlertNotifier,
    required this.onProfileUpdated,
    required this.onSignOut,
  });

  final OnboardingProfile? profile;
  final LocationService? locationService;
  final PlaceSearchService? placeSearchService;
  final RouteService? routeService;
  final JourneyHistoryRepository? journeyHistoryRepository;
  final ActiveJourneyRepository? activeJourneyRepository;
  final ArrivalAlertNotifier? arrivalAlertNotifier;
  final Future<void> Function(OnboardingProfile profile) onProfileUpdated;
  final Future<void> Function() onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  _JourneyFlow _journeyFlow = _JourneyFlow.none;
  ActiveJourney? _activeJourney;
  bool _showProfile = false;
  bool _isRecoveringJourney = true;
  JourneyRoute? _recoveredRoute;
  late final LocationService _locationService =
      widget.locationService ?? GeolocatorLocationService();
  late final RouteService _routeService =
      widget.routeService ?? OpenRouteService();
  late final ActiveJourneyRepository _activeJourneyRepository =
      widget.activeJourneyRepository ??
      SharedPreferencesActiveJourneyRepository();
  late final JourneyHistoryRepository _historyRepository =
      widget.journeyHistoryRepository ??
      SharedPreferencesJourneyHistoryRepository();
  List<JourneyHistoryEntry> _journeyHistory = const [];
  bool _historyLoading = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadJourneyHistory();
    _recoverActiveJourney();
  }

  Future<void> _recoverActiveJourney() async {
    try {
      final savedJourney = await _activeJourneyRepository.loadActiveJourney();
      if (savedJourney == null) return;

      final locationResult = await _locationService
          .getCurrentLocation()
          .timeout(const Duration(seconds: 15));
      final currentLocation = locationResult.location;
      if (currentLocation == null) return;

      final route = await _routeService
          .getRoute(
            start: savedJourney.startingLocation,
            destination: savedJourney.destination,
          )
          .timeout(const Duration(seconds: 15));
      if (!_isValidRoute(route) || !mounted) return;

      setState(() {
        _activeJourney = savedJourney.withCurrentLocation(currentLocation);
        _recoveredRoute = route;
        _journeyFlow = _JourneyFlow.liveJourney;
      });
    } catch (_) {
      // Keep valid saved state pending for the next launch if a dependency is
      // temporarily unavailable. Tracking remains stopped until recovery works.
    } finally {
      if (mounted) setState(() => _isRecoveringJourney = false);
    }
  }

  bool _isValidRoute(JourneyRoute route) =>
      route.distanceMeters.isFinite &&
      route.distanceMeters >= 0 &&
      route.durationSeconds.isFinite &&
      route.durationSeconds >= 0 &&
      route.geometry.length >= 2 &&
      route.geometry.every(
        (point) =>
            point.latitude.isFinite &&
            point.longitude.isFinite &&
            point.latitude >= -90 &&
            point.latitude <= 90 &&
            point.longitude >= -180 &&
            point.longitude <= 180,
      );

  Future<void> _loadJourneyHistory() async {
    try {
      final history = await _historyRepository.getHistory();
      if (!mounted) return;
      setState(() {
        _journeyHistory = history;
        _historyLoading = false;
        _historyError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = 'Journey history could not be loaded from this device.';
      });
    }
  }

  void _openDestinationPicker() =>
      setState(() => _journeyFlow = _JourneyFlow.destination);

  void _returnToLiveJourney() =>
      setState(() => _journeyFlow = _JourneyFlow.liveJourney);

  Future<void> _confirmDestination(
    Destination destination,
    CurrentLocation currentLocation,
  ) async {
    final journey = ActiveJourney(
      startingLocation: currentLocation,
      currentLocation: currentLocation,
      destination: destination,
      startedAt: DateTime.now(),
    );
    await _activeJourneyRepository.saveActiveJourney(journey);
    if (!mounted) return;
    setState(() {
      _activeJourney = journey;
      _recoveredRoute = null;
      _journeyFlow = _JourneyFlow.liveJourney;
    });
  }

  Future<void> _persistArrivalAlertTriggered(ActiveJourney journey) async {
    await _activeJourneyRepository.saveActiveJourney(journey);
    _activeJourney = journey;
  }

  void _closeDestinationPicker() =>
      setState(() => _journeyFlow = _JourneyFlow.none);

  Future<void> _endJourney(JourneyHistoryStatus status) async {
    final journey = _activeJourney;
    if (journey == null) return;
    final historyEntry = JourneyHistoryEntry(
      destination: journey.destination.name,
      startedAt: journey.startedAt,
      endedAt: DateTime.now(),
      status: status,
    );
    try {
      await _activeJourneyRepository.clearActiveJourney();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not safely end this journey. Please retry.'),
        ),
      );
      return;
    }
    setState(() {
      _activeJourney = null;
      _recoveredRoute = null;
      _journeyFlow = _JourneyFlow.none;
      _historyLoading = true;
      _historyError = null;
    });
    try {
      await _historyRepository.addJourney(historyEntry);
      final history = await _historyRepository.getHistory();
      if (!mounted) return;
      setState(() {
        _journeyHistory = history;
        _historyLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _historyLoading = false;
        _historyError = 'Journey ended, but its history could not be saved.';
      });
    }
  }

  Future<void> _updateProfile(OnboardingProfile profile) async {
    await widget.onProfileUpdated(profile);
    if (mounted) setState(() => _showProfile = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRecoveringJourney) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Checking for an active journey…'),
              ],
            ),
          ),
        ),
      );
    }
    if (_showProfile) {
      return ProfileScreen(
        profile: widget.profile,
        onBack: () => setState(() => _showProfile = false),
        onSave: _updateProfile,
        onSignOut: widget.onSignOut,
      );
    }
    if (_journeyFlow == _JourneyFlow.destination) {
      return DestinationScreen(
        onBack: _closeDestinationPicker,
        locationService: _locationService,
        placeSearchService:
            widget.placeSearchService ??
            (widget.locationService is PlaceSearchService
                ? widget.locationService! as PlaceSearchService
                : MapTilerPlaceSearchService(apiKey: MapTilerConfig.apiKey)),
        onConfirm: _confirmDestination,
      );
    }
    if (_journeyFlow == _JourneyFlow.liveJourney && _activeJourney != null) {
      return LiveJourneyScreen(
        journey: _activeJourney!,
        locationService: _locationService,
        routeService: _routeService,
        initialRoute: _recoveredRoute,
        arrivalAlertNotifier: widget.arrivalAlertNotifier,
        onArrivalAlertTriggered: _persistArrivalAlertTriggered,
        onCancelJourney: () => _endJourney(JourneyHistoryStatus.cancelled),
        onFinishJourney: () => _endJourney(JourneyHistoryStatus.completed),
        onPreviewApproaching: () =>
            setState(() => _journeyFlow = _JourneyFlow.approachingPreview),
        onPreviewArrival: () =>
            setState(() => _journeyFlow = _JourneyFlow.arrivalPreview),
      );
    }
    if ((_journeyFlow == _JourneyFlow.approachingPreview ||
            _journeyFlow == _JourneyFlow.arrivalPreview) &&
        _activeJourney != null) {
      return ArrivalAlertScreen(
        destination: _activeJourney!.destination,
        isReached: _journeyFlow == _JourneyFlow.arrivalPreview,
        onClose: _returnToLiveJourney,
        onShowReached: () =>
            setState(() => _journeyFlow = _JourneyFlow.arrivalPreview),
      );
    }

    final screens = <Widget>[
      HomeScreen(
        onStartJourney: _openDestinationPicker,
        userName: widget.profile?.fullName,
        onOpenProfile: () => setState(() => _showProfile = true),
      ),
      JourneyHistoryScreen(
        journeys: _journeyHistory,
        isLoading: _historyLoading,
        loadError: _historyError,
      ),
      const PlaceholderScreen(
        icon: Icons.settings_outlined,
        title: 'Settings',
        message:
            'Manage your alert preferences, privacy controls, and travel settings here.',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Journeys',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
