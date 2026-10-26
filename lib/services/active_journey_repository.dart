import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_journey.dart';

abstract interface class ActiveJourneyRepository {
  Future<ActiveJourney?> loadActiveJourney();
  Future<void> saveActiveJourney(ActiveJourney journey);
  Future<void> clearActiveJourney();
}

class SharedPreferencesActiveJourneyRepository
    implements ActiveJourneyRepository {
  static const _key = 'arrivio_active_journey';

  @override
  Future<ActiveJourney?> loadActiveJourney() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return ActiveJourney.fromJson(jsonDecode(encoded));
    } catch (_) {
      await preferences.remove(_key);
      return null;
    }
  }

  @override
  Future<void> saveActiveJourney(ActiveJourney journey) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key,
      jsonEncode(journey.toJson()),
    );
    if (!saved) throw StateError('Local preferences rejected the journey.');
  }

  @override
  Future<void> clearActiveJourney() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key);
  }
}

class InMemoryActiveJourneyRepository implements ActiveJourneyRepository {
  InMemoryActiveJourneyRepository({ActiveJourney? journey}) {
    _journey = journey;
  }

  ActiveJourney? _journey;

  @override
  Future<ActiveJourney?> loadActiveJourney() async => _journey;

  @override
  Future<void> saveActiveJourney(ActiveJourney journey) async {
    _journey = journey;
  }

  @override
  Future<void> clearActiveJourney() async {
    _journey = null;
  }
}
