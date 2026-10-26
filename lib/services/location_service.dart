import 'package:geolocator/geolocator.dart';

import '../models/current_location.dart';

enum LocationFailure {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationResult {
  const LocationResult._({this.location, this.failure, this.message});
  const LocationResult.success(CurrentLocation location)
    : this._(location: location);
  const LocationResult.failure(LocationFailure failure, String message)
    : this._(failure: failure, message: message);

  final CurrentLocation? location;
  final LocationFailure? failure;
  final String? message;
  bool get isSuccess => location != null;
}

class LocationTrackingException implements Exception {
  const LocationTrackingException(this.failure, this.message);
  final LocationFailure failure;
  final String message;
}

abstract class LocationService {
  Future<LocationResult> getCurrentLocation();
  Stream<CurrentLocation> watchLocation();
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationResult> getCurrentLocation() async {
    try {
      final availabilityFailure = await _availabilityFailure();
      if (availabilityFailure != null) return availabilityFailure;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult.success(
        CurrentLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: position.timestamp,
        ),
      );
    } on LocationServiceDisabledException {
      return const LocationResult.failure(
        LocationFailure.servicesDisabled,
        'Turn on location services and try again.',
      );
    } on PermissionDeniedException {
      return const LocationResult.failure(
        LocationFailure.permissionDenied,
        'Location permission is needed to start a journey.',
      );
    } catch (_) {
      return const LocationResult.failure(
        LocationFailure.unavailable,
        'We could not determine your current location. Check your signal or emulator location and try again.',
      );
    }
  }

  @override
  Stream<CurrentLocation> watchLocation() async* {
    final availabilityFailure = await _availabilityFailure();
    if (availabilityFailure != null) {
      throw LocationTrackingException(
        availabilityFailure.failure!,
        availabilityFailure.message!,
      );
    }
    try {
      yield* Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map(_toCurrentLocation);
    } on LocationServiceDisabledException {
      throw const LocationTrackingException(
        LocationFailure.servicesDisabled,
        'Location services were turned off. Turn them on to resume live tracking.',
      );
    } on PermissionDeniedException {
      throw const LocationTrackingException(
        LocationFailure.permissionDenied,
        'Location permission was revoked. Allow it to resume live tracking.',
      );
    } catch (_) {
      throw const LocationTrackingException(
        LocationFailure.unavailable,
        'Live location is temporarily unavailable. We will keep your journey open.',
      );
    }
  }

  Future<LocationResult?> _availabilityFailure() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult.failure(
        LocationFailure.servicesDisabled,
        'Turn on location services to use your current position as the journey start.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const LocationResult.failure(
        LocationFailure.permissionDenied,
        'Location permission is needed to start a journey from your current position.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const LocationResult.failure(
        LocationFailure.permissionDeniedForever,
        'Location permission is turned off for ArrivioAI. Enable it in app settings to continue.',
      );
    }
    return null;
  }

  CurrentLocation _toCurrentLocation(Position position) => CurrentLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    timestamp: position.timestamp,
  );

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
