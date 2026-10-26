/// A foreground GPS snapshot. The optional [label] leaves room for reverse
/// geocoding later without making location acquisition depend on it.
class CurrentLocation {
  const CurrentLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.label = 'Current location',
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String label;
}
