import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/models/current_location.dart';
import 'package:mobile/models/destination.dart';
import 'package:mobile/services/route_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final start = CurrentLocation(
    latitude: 1,
    longitude: 2,
    timestamp: DateTime.utc(2026),
  );
  const destination = Destination(
    name: 'Destination',
    address: 'Destination address',
    latitude: 3,
    longitude: 4,
  );

  test('logs status and sanitized ORS message, preserving user error', () async {
    const secret = 'test-secret-value';
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final service = OpenRouteService(
      apiKey: secret,
      client: MockClient((request) async {
        expect(request.headers['Authorization'], secret);
        return http.Response(
          '{"error":{"message":"Key $secret rejected"}}',
          401,
        );
      }),
    );

    await expectLater(
      service.getRoute(start: start, destination: destination),
      throwsA(
        isA<RouteServiceException>().having(
          (error) => error.message,
          'message',
          'We could not load the road route. Please try again.',
        ),
      ),
    );

    expect(messages, hasLength(1));
    expect(messages.single, contains('HTTP 401'));
    expect(messages.single, contains('Key [REDACTED] rejected'));
    expect(messages.single, isNot(contains(secret)));
  });

  test('logs status when the response has no ORS error message', () async {
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final service = OpenRouteService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('{}', 503)),
    );

    await expectLater(
      service.getRoute(start: start, destination: destination),
      throwsA(isA<RouteServiceException>()),
    );
    expect(messages, ['OpenRouteService HTTP 503']);
  });
}
