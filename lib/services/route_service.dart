import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/current_location.dart';
import '../models/destination.dart';
import '../models/route.dart';
import 'open_route_service_config.dart';

class RouteServiceException implements Exception {
  const RouteServiceException(this.message);
  final String message;
}

abstract class RouteService {
  Future<JourneyRoute> getRoute({
    required CurrentLocation start,
    required Destination destination,
  });
}

/// ORS Directions GeoJSON client. The `/geojson` response avoids encoded
/// polylines, while ORS still receives coordinates as `[longitude, latitude]`.
class OpenRouteService implements RouteService {
  OpenRouteService({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? OpenRouteServiceConfig.apiKey;

  final http.Client _client;
  final String _apiKey;
  static final _endpoint = Uri.parse(
    'https://api.heigit.org/openrouteservice/v2/directions/driving-car/geojson',
  );

  @override
  Future<JourneyRoute> getRoute({
    required CurrentLocation start,
    required Destination destination,
  }) async {
    if (_apiKey.isEmpty) {
      throw const RouteServiceException(
        'Routing setup needed. Add OPENROUTESERVICE_API_KEY with --dart-define to use road routes.',
      );
    }
    try {
      final response = await _client.post(
        _endpoint,
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/geo+json',
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude],
            [destination.longitude, destination.latitude],
          ],
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logHttpError(response.statusCode, response.body);
        throw const RouteServiceException(
          'We could not load the road route. Please try again.',
        );
      }
      return _parse(response.body);
    } on RouteServiceException {
      rethrow;
    } catch (_) {
      throw const RouteServiceException(
        'We could not load the road route. Check your connection and try again.',
      );
    }
  }

  void _logHttpError(int statusCode, String body) {
    String? message;
    try {
      final root = jsonDecode(body);
      if (root is Map<String, dynamic>) {
        final error = root['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          message = error['message'] as String;
        }
      }
    } catch (_) {
      // Some gateways return non-JSON error bodies; never log the raw body.
    }

    var safeMessage = message?.replaceAll(_apiKey, '[REDACTED]') ?? '';
    safeMessage = safeMessage
        .replaceAll(
          RegExp(
            r'(authorization\s*[:=]\s*)(?:bearer\s+)?[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1[REDACTED]',
        )
        .replaceAll(
          RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAll(
          RegExp(
            r'(\b(?:api[_-]?key|access[_-]?token|token)\b\s*[:=]\s*)[^\s,;]+',
            caseSensitive: false,
          ),
          r'$1[REDACTED]',
        )
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    if (safeMessage.length > 300) {
      safeMessage = '${safeMessage.substring(0, 300)}…';
    }
    debugPrint(
      'OpenRouteService HTTP $statusCode${safeMessage.isEmpty ? '' : ': $safeMessage'}',
    );
  }

  JourneyRoute _parse(String body) {
    try {
      final root = jsonDecode(body) as Map<String, dynamic>;
      final features = root['features'] as List<dynamic>;
      if (features.isEmpty) throw const FormatException();
      final feature = features.first as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>;
      final summary = properties['summary'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final rawCoordinates = geometry['coordinates'] as List<dynamic>;
      final coordinates = rawCoordinates
          .map((point) {
            final values = point as List<dynamic>;
            if (values.length < 2 || values[0] is! num || values[1] is! num) {
              throw const FormatException();
            }
            return RouteCoordinate(
              latitude: (values[1] as num).toDouble(),
              longitude: (values[0] as num).toDouble(),
            );
          })
          .toList(growable: false);
      final distance = summary['distance'];
      final duration = summary['duration'];
      if (coordinates.length < 2 || distance is! num || duration is! num) {
        throw const FormatException();
      }
      return JourneyRoute(
        distanceMeters: distance.toDouble(),
        durationSeconds: duration.toDouble(),
        geometry: coordinates,
      );
    } catch (_) {
      throw const RouteServiceException(
        'The route service returned an invalid route. Please try again.',
      );
    }
  }
}
