import 'current_location.dart';
import 'destination.dart';

/// State for an active journey, including the details needed to recover it.
class ActiveJourney {
  const ActiveJourney({
    required this.startingLocation,
    required this.currentLocation,
    required this.destination,
    required this.startedAt,
    this.arrivalAlertTriggered = false,
  });

  final CurrentLocation startingLocation;
  final CurrentLocation currentLocation;
  final Destination destination;
  final DateTime startedAt;
  final bool arrivalAlertTriggered;

  ActiveJourney withCurrentLocation(CurrentLocation location) => ActiveJourney(
    startingLocation: startingLocation,
    currentLocation: location,
    destination: destination,
    startedAt: startedAt,
    arrivalAlertTriggered: arrivalAlertTriggered,
  );

  ActiveJourney withArrivalAlertTriggered([bool triggered = true]) =>
      ActiveJourney(
        startingLocation: startingLocation,
        currentLocation: currentLocation,
        destination: destination,
        startedAt: startedAt,
        arrivalAlertTriggered: triggered,
      );

  Map<String, Object> toJson() => {
    'startingLocation': _locationToJson(startingLocation),
    'currentLocation': _locationToJson(currentLocation),
    'destination': {
      'name': destination.name,
      'address': destination.address,
      'latitude': destination.latitude,
      'longitude': destination.longitude,
    },
    'startedAt': startedAt.toIso8601String(),
    'arrivalAlertTriggered': arrivalAlertTriggered,
  };

  factory ActiveJourney.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Saved journey must be an object.');
    }
    final rawDestination = value['destination'];
    final startedAt = value['startedAt'];
    if (rawDestination is! Map<String, dynamic> || startedAt is! String) {
      throw const FormatException('Saved journey is incomplete.');
    }
    final name = rawDestination['name'];
    final address = rawDestination['address'];
    final latitude = rawDestination['latitude'];
    final longitude = rawDestination['longitude'];
    if (name is! String ||
        name.trim().isEmpty ||
        address is! String ||
        address.trim().isEmpty ||
        latitude is! num ||
        longitude is! num) {
      throw const FormatException('Saved destination is invalid.');
    }
    final start = _locationFromJson(value['startingLocation']);
    final current = _locationFromJson(value['currentLocation']);
    final destinationLatitude = latitude.toDouble();
    final destinationLongitude = longitude.toDouble();
    if (!_validCoordinates(destinationLatitude, destinationLongitude)) {
      throw const FormatException('Saved destination coordinates are invalid.');
    }
    return ActiveJourney(
      startingLocation: start,
      currentLocation: current,
      destination: Destination(
        name: name,
        address: address,
        latitude: destinationLatitude,
        longitude: destinationLongitude,
      ),
      startedAt: DateTime.parse(startedAt),
      arrivalAlertTriggered: value['arrivalAlertTriggered'] == true,
    );
  }
}

Map<String, Object> _locationToJson(CurrentLocation location) => {
  'latitude': location.latitude,
  'longitude': location.longitude,
  'timestamp': location.timestamp.toIso8601String(),
  'label': location.label,
};

CurrentLocation _locationFromJson(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Saved location is incomplete.');
  }
  final latitude = value['latitude'];
  final longitude = value['longitude'];
  final timestamp = value['timestamp'];
  final label = value['label'];
  if (latitude is! num || longitude is! num || timestamp is! String) {
    throw const FormatException('Saved location is invalid.');
  }
  final parsedLatitude = latitude.toDouble();
  final parsedLongitude = longitude.toDouble();
  if (!_validCoordinates(parsedLatitude, parsedLongitude)) {
    throw const FormatException('Saved location coordinates are invalid.');
  }
  return CurrentLocation(
    latitude: parsedLatitude,
    longitude: parsedLongitude,
    timestamp: DateTime.parse(timestamp),
    label: label is String ? label : 'Current location',
  );
}

bool _validCoordinates(double latitude, double longitude) =>
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
