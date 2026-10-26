/// A latitude/longitude coordinate suitable for Flutter map rendering.
class RouteCoordinate {
  const RouteCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// The initial road route for an active journey.
class JourneyRoute {
  const JourneyRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });

  final double distanceMeters;
  final double durationSeconds;
  final List<RouteCoordinate> geometry;
}
