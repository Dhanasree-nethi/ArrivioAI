import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../models/current_location.dart';
import '../models/destination.dart';

const arrivalAlertRadiusMeters = 500.0;
const _arrivalSoundChannel = MethodChannel('com.arrivioai.mobile/arrival_alert');

double distanceToDestinationMeters(
  CurrentLocation location,
  Destination destination,
) {
  const earthRadiusMeters = 6371000.0;
  final radians = math.pi / 180;
  final latitudeDelta = (destination.latitude - location.latitude) * radians;
  final longitudeDelta = (destination.longitude - location.longitude) * radians;
  final a =
      math.pow(math.sin(latitudeDelta / 2), 2) +
      math.cos(location.latitude * radians) *
          math.cos(destination.latitude * radians) *
          math.pow(math.sin(longitudeDelta / 2), 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

abstract interface class ArrivalAlertNotifier {
  Future<void> notifyArrivalApproaching();
}

class DeviceArrivalAlertNotifier implements ArrivalAlertNotifier {
  @override
  Future<void> notifyArrivalApproaching() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _arrivalSoundChannel.invokeMethod<void>('playNotificationSound');
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {
      // Keep vibration and the on-screen message available without system audio.
    }
    try {
      await HapticFeedback.vibrate();
    } catch (_) {
      // Haptics may be unavailable or disabled on the device.
    }
  }
}
