import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journey_history_entry.dart';

abstract interface class JourneyHistoryRepository {
  Future<List<JourneyHistoryEntry>> getHistory();
  Future<void> addJourney(JourneyHistoryEntry journey);
}

class SharedPreferencesJourneyHistoryRepository
    implements JourneyHistoryRepository {
  static const _key = 'arrivio_journey_history';

  @override
  Future<List<JourneyHistoryEntry>> getHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null || encoded.isEmpty) return const [];
    final records = jsonDecode(encoded) as List<dynamic>;
    return records
        .map(
          (record) => JourneyHistoryEntry.fromJson(
            record as Map<String, dynamic>,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> addJourney(JourneyHistoryEntry journey) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    final existing = encoded == null || encoded.isEmpty
        ? <JourneyHistoryEntry>[]
        : (jsonDecode(encoded) as List<dynamic>)
              .map(
                (record) => JourneyHistoryEntry.fromJson(
                  record as Map<String, dynamic>,
                ),
              )
              .toList();
    await preferences.setString(
      _key,
      jsonEncode([journey, ...existing].map((entry) => entry.toJson()).toList()),
    );
  }
}

class InMemoryJourneyHistoryRepository implements JourneyHistoryRepository {
  InMemoryJourneyHistoryRepository({List<JourneyHistoryEntry>? journeys})
    : _journeys = List.of(journeys ?? const []);

  final List<JourneyHistoryEntry> _journeys;

  @override
  Future<List<JourneyHistoryEntry>> getHistory() async =>
      List.unmodifiable(_journeys);

  @override
  Future<void> addJourney(JourneyHistoryEntry journey) async =>
      _journeys.insert(0, journey);
}
