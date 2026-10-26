import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/active_journey.dart';
import '../models/current_location.dart';
import '../models/destination.dart';
import '../models/route.dart';
import '../services/location_service.dart';
import '../services/arrival_alert_service.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../widgets/map_preview.dart';

class LiveJourneyScreen extends StatefulWidget {
  const LiveJourneyScreen({
    super.key,
    required this.journey,
    required this.locationService,
    required this.routeService,
    this.initialRoute,
    required this.onArrivalAlertTriggered,
    this.arrivalAlertNotifier,
    required this.onCancelJourney,
    required this.onFinishJourney,
    required this.onPreviewApproaching,
    required this.onPreviewArrival,
  });
  final ActiveJourney journey;
  final LocationService locationService;
  final RouteService routeService;
  final JourneyRoute? initialRoute;
  final Future<void> Function(ActiveJourney journey) onArrivalAlertTriggered;
  final ArrivalAlertNotifier? arrivalAlertNotifier;
  final VoidCallback onCancelJourney;
  final VoidCallback onFinishJourney;
  final VoidCallback onPreviewApproaching;
  final VoidCallback onPreviewArrival;
  @override
  State<LiveJourneyScreen> createState() => _LiveJourneyScreenState();
}

class _LiveJourneyScreenState extends State<LiveJourneyScreen> {
  late ActiveJourney _journey;
  StreamSubscription<CurrentLocation>? _locationSubscription;
  bool _awaitingFirstUpdate = true;
  String? _trackingMessage;
  JourneyRoute? _route;
  String? _routeMessage;
  bool _isRouteLoading = true;
  bool _arrivalAlertClaimed = false;
  bool _arrivalAlertVisible = false;

  double get _journeyProgress {
    final route = _route;
    if (route != null && route.geometry.length >= 2) {
      return _progressAlongRoute(route);
    }

    return _straightLineProgress;
  }

  double get _straightLineProgress {
    final total = _distanceBetween(
      _journey.startingLocation.latitude,
      _journey.startingLocation.longitude,
      _journey.destination.latitude,
      _journey.destination.longitude,
    );
    if (total == 0) return 1;
    final travelled = _distanceBetween(
      _journey.startingLocation.latitude,
      _journey.startingLocation.longitude,
      _journey.currentLocation.latitude,
      _journey.currentLocation.longitude,
    );
    final remaining = _distanceBetween(
      _journey.currentLocation.latitude,
      _journey.currentLocation.longitude,
      _journey.destination.latitude,
      _journey.destination.longitude,
    );
    return (travelled / (travelled + remaining)).clamp(0.0, 1.0);
  }

  double _progressAlongRoute(JourneyRoute route) {
    const earthRadiusMeters = 6371000.0;
    final radians = math.pi / 180;
    final current = _journey.currentLocation;
    final latitudeScale = math.cos(current.latitude * radians);
    final points = route.geometry;
    var totalMeters = 0.0;
    final segmentLengths = <double>[];
    for (var i = 0; i < points.length - 1; i++) {
      final length = _distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
      segmentLengths.add(length);
      totalMeters += length;
    }
    if (totalMeters == 0) return 1;

    double x(RouteCoordinate point) =>
        (point.longitude - current.longitude) *
        radians *
        latitudeScale *
        earthRadiusMeters;
    double y(RouteCoordinate point) =>
        (point.latitude - current.latitude) * radians * earthRadiusMeters;

    var distanceBeforeSegment = 0.0;
    var closestDistanceSquared = double.infinity;
    var distanceAlongRoute = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final startX = x(points[i]);
      final startY = y(points[i]);
      final deltaX = x(points[i + 1]) - startX;
      final deltaY = y(points[i + 1]) - startY;
      final segmentLengthSquared = deltaX * deltaX + deltaY * deltaY;
      final projectedFraction = segmentLengthSquared == 0
          ? 0.0
          : (-(startX * deltaX + startY * deltaY) / segmentLengthSquared)
                .clamp(0.0, 1.0)
                .toDouble();
      final projectedX = startX + projectedFraction * deltaX;
      final projectedY = startY + projectedFraction * deltaY;
      final distanceSquared = projectedX * projectedX + projectedY * projectedY;
      if (distanceSquared < closestDistanceSquared) {
        closestDistanceSquared = distanceSquared;
        distanceAlongRoute =
            distanceBeforeSegment + segmentLengths[i] * projectedFraction;
      }
      distanceBeforeSegment += segmentLengths[i];
    }
    return (distanceAlongRoute / totalMeters).clamp(0.0, 1.0);
  }

  double _distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final radians = math.pi / 180;
    final latitudeDelta = (lat2 - lat1) * radians;
    final longitudeDelta = (lon2 - lon1) * radians;
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(lat1 * radians) *
            math.cos(lat2 * radians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double get _remainingRouteFraction => 1 - _journeyProgress;

  Future<void> _confirmCancellation() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this journey?'),
        content: const Text(
          'Live location tracking will stop and this journey will be discarded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep journey'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel journey'),
          ),
        ],
      ),
    );
    if (shouldCancel == true && mounted) widget.onCancelJourney();
  }

  @override
  void initState() {
    super.initState();
    _journey = widget.journey;
    _route = widget.initialRoute;
    _isRouteLoading = widget.initialRoute == null;
    _arrivalAlertClaimed = widget.journey.arrivalAlertTriggered;
    _arrivalAlertVisible = widget.journey.arrivalAlertTriggered;
    _startTracking();
    _processLocation(_journey.currentLocation);
    if (widget.initialRoute == null) _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _isRouteLoading = true;
      _routeMessage = null;
    });
    try {
      final route = await widget.routeService.getRoute(
        start: _journey.startingLocation,
        destination: _journey.destination,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _isRouteLoading = false;
      });
    } on RouteServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _isRouteLoading = false;
        _routeMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRouteLoading = false;
        _routeMessage = 'We could not load the road route. Please try again.';
      });
    }
  }

  void _startTracking() {
    final previousSubscription = _locationSubscription;
    _locationSubscription = null;
    if (previousSubscription != null) {
      unawaited(previousSubscription.cancel());
    }
    if (!mounted) return;

    setState(() {
      _awaitingFirstUpdate = true;
      _trackingMessage = null;
    });
    _locationSubscription = widget.locationService.watchLocation().listen(
      (location) {
        if (!mounted) return;
        _processLocation(location);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        final message = error is LocationTrackingException
            ? error.message
            : 'Live location is temporarily unavailable. Try again when ready.';
        setState(() {
          _awaitingFirstUpdate = false;
          _trackingMessage = message;
        });
      },
    );
  }

  void _processLocation(CurrentLocation location) {
    final updatedJourney = _journey.withCurrentLocation(location);
    final shouldTriggerAlert =
        !_arrivalAlertClaimed &&
        distanceToDestinationMeters(location, updatedJourney.destination) <=
            arrivalAlertRadiusMeters;
    if (shouldTriggerAlert) _arrivalAlertClaimed = true;
    final journeyForPersistence = shouldTriggerAlert
        ? updatedJourney.withArrivalAlertTriggered()
        : updatedJourney;
    setState(() {
      _journey = journeyForPersistence;
      _awaitingFirstUpdate = false;
      _trackingMessage = null;
    });
    if (shouldTriggerAlert) {
      unawaited(_persistAndNotifyArrival(journeyForPersistence));
    }
  }

  Future<void> _persistAndNotifyArrival(ActiveJourney journey) async {
    try {
      await widget.onArrivalAlertTriggered(journey);
    } catch (_) {
      if (!mounted) return;
      _arrivalAlertClaimed = false;
      setState(() {
        _journey = _journey.withArrivalAlertTriggered(false);
        _trackingMessage =
            'Arrival alert could not be saved. It will retry with the next GPS update.';
      });
      return;
    }
    if (!mounted) return;
    setState(() => _arrivalAlertVisible = true);
    await (widget.arrivalAlertNotifier ?? DeviceArrivalAlertNotifier())
        .notifyArrivalApproaching();
  }

  @override
  void dispose() {
    unawaited(_locationSubscription?.cancel() ?? Future<void>.value());
    _locationSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: _confirmCancellation,
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Cancel journey',
      ),
      title: const Text('Live Journey'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: _TrackingPill(
              isLive: _trackingMessage == null && !_awaitingFirstUpdate,
            ),
          ),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          MapPreview(
            destination: _journey.destination,
            currentLocation: _journey.currentLocation,
            startingLocation: _journey.startingLocation,
            route: _route,
            compact: true,
          ),
          const SizedBox(height: 12),
          if (_isRouteLoading)
            const _RouteMessage(
              message: 'Loading your road route…',
              loading: true,
            )
          else if (_routeMessage != null)
            _RouteMessage(message: _routeMessage!, onRetry: _loadRoute),
          const SizedBox(height: 20),
          _DestinationCard(destination: _journey.destination),
          const SizedBox(height: 12),
          _LocationCard(
            title: 'Starting location',
            location: _journey.startingLocation,
            icon: Icons.trip_origin_rounded,
          ),
          if (_arrivalAlertVisible)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Card(
                key: Key('arrival_proximity_alert'),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_rounded),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your stop is approaching!',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _LocationCard(
            title: 'Current location',
            location: _journey.currentLocation,
            icon: Icons.my_location_rounded,
            key: const Key('live_current_location'),
          ),
          if (_awaitingFirstUpdate)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _TrackingMessage(
                icon: Icons.gps_fixed_rounded,
                message: 'Connecting to live location…',
                loading: true,
              ),
            ),
          if (_trackingMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _TrackingMessage(
                icon: Icons.location_off_rounded,
                message: _trackingMessage!,
                onRetry: _startTracking,
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Distance remaining',
                  value: _route == null
                      ? 'Not available'
                      : formatRouteDistance(
                          _route!.distanceMeters * _remainingRouteFraction,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Metric(
                  label: 'Estimated arrival',
                  value: _route == null
                      ? 'Not available'
                      : formatEstimatedArrival(
                          DateTime.now(),
                          _route!.durationSeconds * _remainingRouteFraction,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Journey progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: _journeyProgress,
            minHeight: 8,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(height: 7),
          Text(
            _awaitingFirstUpdate
                ? 'Progress begins after live location is available.'
                : _trackingMessage == null
                ? 'Live location updates are being received.'
                : 'Progress is paused while live location is unavailable.',
          ),
          const SizedBox(height: 22),
          _LocationStatusCard(
            isLive: _trackingMessage == null && !_awaitingFirstUpdate,
          ),
          const SizedBox(height: 26),
          Text('Alert status', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _AlertStatusCard(destination: _journey.destination),
          const SizedBox(height: 20),
          const _PreviewNotice(),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: widget.onPreviewApproaching,
            child: const Text('Preview approaching alert'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onPreviewArrival,
            child: const Text('Preview destination reached'),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('cancel_journey_button'),
                onPressed: _confirmCancellation,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel journey'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('finish_journey_button'),
                onPressed: widget.onFinishJourney,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Finish journey'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TrackingPill extends StatelessWidget {
  const _TrackingPill({required this.isLive});
  final bool isLive;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: isLive ? const Color(0xFFE8F7EE) : const Color(0xFFF2F4F7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isLive ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
          size: 14,
          color: isLive ? const Color(0xFF067647) : AppTheme.mutedInk,
        ),
        const SizedBox(width: 5),
        Text(
          isLive ? 'Live' : 'Connecting',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isLive ? const Color(0xFF067647) : AppTheme.mutedInk,
          ),
        ),
      ],
    ),
  );
}

String formatRouteDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
}

String formatEstimatedArrival(DateTime now, double durationSeconds) {
  final arrival = now.add(Duration(seconds: durationSeconds.round()));
  final hour = arrival.hour % 12 == 0 ? 12 : arrival.hour % 12;
  final minute = arrival.minute.toString().padLeft(2, '0');
  final period = arrival.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

class _RouteMessage extends StatelessWidget {
  const _RouteMessage({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    key: Key(loading ? 'route_loading_state' : 'route_error_state'),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.route_rounded, color: AppTheme.mutedInk),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            TextButton(
              key: const Key('retry_route_button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    ),
  );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard({required this.destination});
  final Destination destination;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFFE45B4F),
            ),
          ),
          const SizedBox(width: 14),
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
                Text(
                  destination.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.location,
    required this.icon,
    super.key,
  });
  final String title;
  final CurrentLocation location;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.blue),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.mutedInk,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                location.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                ),
              ),
              Text(
                '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.mutedInk),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.isLive});
  final bool isLive;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isLive ? Icons.gps_fixed_rounded : Icons.location_searching_rounded,
            color: isLive ? const Color(0xFF067647) : AppTheme.mutedInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLive
                      ? 'Live location is active'
                      : 'Live location is connecting',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLive
                      ? 'Your current position updates while this journey is open.'
                      : 'Waiting for your first foreground location update.',
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrackingMessage extends StatelessWidget {
  const _TrackingMessage({
    required this.icon,
    required this.message,
    this.loading = false,
    this.onRetry,
  });
  final IconData icon;
  final String message;
  final bool loading;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, color: AppTheme.mutedInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: AppTheme.mutedInk),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: const Key('retry_tracking_button'),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    ),
  );
}

class _AlertStatusCard extends StatelessWidget {
  const _AlertStatusCard({required this.destination});
  final Destination destination;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_paused_outlined,
              color: Color(0xFFB54708),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arrival alert is standing by',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 3),
                Text('Alerts will activate when location tracking is enabled.'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();
  @override
  Widget build(BuildContext context) => const Text(
    'Preview-only alert states below — these do not use live GPS or send notifications.',
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
  );
}
