enum JourneyHistoryStatus { completed, cancelled }

class JourneyHistoryEntry {
  const JourneyHistoryEntry({
    required this.destination,
    required this.startedAt,
    required this.endedAt,
    required this.status,
  });

  final String destination;
  final DateTime startedAt;
  final DateTime endedAt;
  final JourneyHistoryStatus status;

  Map<String, Object> toJson() => {
    'destination': destination,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'status': status.name,
  };

  factory JourneyHistoryEntry.fromJson(Map<String, dynamic> json) {
    final statusName = json['status'];
    final status = JourneyHistoryStatus.values
        .where((value) => value.name == statusName)
        .firstOrNull;
    final destination = json['destination'];
    final startedAt = json['startedAt'];
    final endedAt = json['endedAt'];
    if (destination is! String ||
        startedAt is! String ||
        endedAt is! String ||
        status == null) {
      throw const FormatException('Invalid journey history entry.');
    }
    return JourneyHistoryEntry(
      destination: destination,
      startedAt: DateTime.parse(startedAt),
      endedAt: DateTime.parse(endedAt),
      status: status,
    );
  }
}
