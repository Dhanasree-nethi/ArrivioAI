import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/current_location.dart';
import '../models/destination.dart';

abstract class PlaceSearchService {
  Future<List<Destination>> searchPlaces(String query, {CurrentLocation? near});
}

class PlaceSearchException implements Exception {
  const PlaceSearchException(this.message);
  final String message;
}

/// MapTiler's forward-geocoding API. It is deliberately called only after a
/// user submits a query; no keystroke autocomplete is performed.
class MapTilerPlaceSearchService implements PlaceSearchService {
  MapTilerPlaceSearchService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<List<Destination>> searchPlaces(
    String query, {
    CurrentLocation? near,
  }) async {
    if (apiKey.isEmpty) {
      throw const PlaceSearchException(
        'Map search needs a MapTiler API key. Ask the app developer to configure it.',
      );
    }

    final parameters = <String, String>{
      'key': apiKey,
      'limit': '6',
      'autocomplete': 'false',
    };
    if (near != null) {
      parameters['proximity'] = '${near.longitude},${near.latitude}';
    }
    final uri = Uri.https(
      'api.maptiler.com',
      '/geocoding/${Uri.encodeComponent(query)}.json',
      parameters,
    );

    try {
      final response = await _client.get(uri);
      _debugRequestResult(uri, response.statusCode);
      if (response.statusCode == 403) {
        throw const PlaceSearchException(
          'Map search is unavailable because the MapTiler key is missing, invalid, or restricted.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const PlaceSearchException(
          'We could not search for places right now. Please try again.',
        );
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final features = payload['features'] as List<dynamic>? ?? const [];
      return features
          .map(
            (feature) =>
                _destinationFromFeature(feature as Map<String, dynamic>),
          )
          .whereType<Destination>()
          .toList(growable: false);
    } on PlaceSearchException {
      rethrow;
    } catch (error) {
      _debugRequestFailure(uri, error);
      throw const PlaceSearchException(
        'We could not reach place search. Check your connection and try again.',
      );
    }
  }

  void _debugRequestResult(Uri uri, int statusCode) {
    assert(() {
      debugPrint(
        'MapTiler place search: ${uri.replace(queryParameters: {...uri.queryParameters, 'key': '<redacted>'})} ($statusCode)',
      );
      return true;
    }());
  }

  void _debugRequestFailure(Uri uri, Object error) {
    assert(() {
      debugPrint(
        'MapTiler place search failed for ${uri.path}: ${error.runtimeType}',
      );
      return true;
    }());
  }

  Destination? _destinationFromFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.length < 2) return null;
    final longitude = (coordinates[0] as num?)?.toDouble();
    final latitude = (coordinates[1] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    final properties =
        feature['properties'] as Map<String, dynamic>? ?? const {};
    final name = feature['text'] as String? ?? properties['name'] as String?;
    final address =
        properties['place_name'] as String? ??
        properties['label'] as String? ??
        feature['place_name'] as String? ??
        name;
    if (name == null || address == null) return null;
    return Destination(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
