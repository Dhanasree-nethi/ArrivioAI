import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart';
import 'package:mobile/models/current_location.dart';
import 'package:mobile/models/active_journey.dart';
import 'package:mobile/models/destination.dart';
import 'package:mobile/models/journey_history_entry.dart';
import 'package:mobile/screens/destination_screen.dart';
import 'package:mobile/screens/live_journey_screen.dart';
import 'package:mobile/services/location_service.dart';
import 'package:mobile/services/active_journey_repository.dart';
import 'package:mobile/services/arrival_alert_service.dart';
import 'package:mobile/services/journey_history_repository.dart';
import 'package:mobile/services/map_tiler_config.dart';
import 'package:mobile/services/onboarding_repository.dart';
import 'package:mobile/services/place_search_service.dart';
import 'package:mobile/services/route_service.dart';
import 'package:mobile/models/route.dart';

class FakeLocationService implements LocationService {
  FakeLocationService(
    this.result, {
    Stream<CurrentLocation>? stream,
    this.watchStreams,
  }) : _stream = stream ?? const Stream.empty();
  final Future<LocationResult> result;
  final Stream<CurrentLocation> _stream;
  final List<Stream<CurrentLocation>>? watchStreams;
  int watchCalls = 0;
  int activeWatchers = 0;
  int forwardedErrors = 0;
  @override
  Future<LocationResult> getCurrentLocation() => result;
  @override
  Stream<CurrentLocation> watchLocation() {
    final index = watchCalls < (watchStreams?.length ?? 0)
        ? watchCalls
        : (watchStreams?.length ?? 1) - 1;
    final source = watchStreams == null ? _stream : watchStreams![index];
    watchCalls++;
    late StreamSubscription<CurrentLocation> subscription;
    late StreamController<CurrentLocation> controller;
    controller = StreamController<CurrentLocation>(
      onListen: () {
        activeWatchers++;
        subscription = source.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            forwardedErrors++;
            controller.addError(error, stackTrace);
          },
          onDone: controller.close,
        );
      },
      onCancel: () {
        activeWatchers--;
        unawaited(subscription.cancel());
      },
    );
    return controller.stream;
  }

  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

class FakePlaceSearchService implements PlaceSearchService {
  FakePlaceSearchService(this.handler);
  final Future<List<Destination>> Function(String query) handler;
  final queries = <String>[];
  @override
  Future<List<Destination>> searchPlaces(
    String query, {
    CurrentLocation? near,
  }) {
    queries.add(query);
    return handler(query);
  }
}

class FakeRouteService implements RouteService {
  FakeRouteService(this.handler);
  final Future<JourneyRoute> Function(CurrentLocation, Destination) handler;
  int calls = 0;

  @override
  Future<JourneyRoute> getRoute({
    required CurrentLocation start,
    required Destination destination,
  }) {
    calls++;
    return handler(start, destination);
  }
}

class FakeArrivalAlertNotifier implements ArrivalAlertNotifier {
  int calls = 0;

  @override
  Future<void> notifyArrivalApproaching() async {
    calls++;
  }
}

const _hitech = Destination(
  name: 'Hitech City, Hyderabad',
  address: 'Madhapur, Hyderabad, Telangana',
  latitude: 17.4435,
  longitude: 78.3772,
);
final _start = CurrentLocation(
  latitude: 17.385,
  longitude: 78.4867,
  timestamp: DateTime(2026, 8, 29),
);
final _update = CurrentLocation(
  latitude: 17.4,
  longitude: 78.5,
  timestamp: DateTime(2026, 8, 29, 10),
);

FakePlaceSearchService successfulSearch() =>
    FakePlaceSearchService((_) async => const [_hitech]);

Future<void> pumpApp(
  WidgetTester tester,
  LocationService location,
  PlaceSearchService search, {
  RouteService? routeService,
  JourneyHistoryRepository? historyRepository,
  ActiveJourneyRepository? activeJourneyRepository,
  ArrivalAlertNotifier? arrivalAlertNotifier,
}) async {
  await tester.pumpWidget(
    ArrivioApp(
      onboardingRepository: InMemoryOnboardingRepository(completed: true),
      locationService: location,
      placeSearchService: search,
      routeService: routeService,
      journeyHistoryRepository:
          historyRepository ?? InMemoryJourneyHistoryRepository(),
      activeJourneyRepository:
          activeJourneyRepository ?? InMemoryActiveJourneyRepository(),
      arrivalAlertNotifier: arrivalAlertNotifier,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> pumpDialogTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

const _route = JourneyRoute(
  distanceMeters: 2450,
  durationSeconds: 900,
  geometry: [
    RouteCoordinate(latitude: 17.385, longitude: 78.4867),
    RouteCoordinate(latitude: 17.4, longitude: 78.45),
    RouteCoordinate(latitude: 17.4435, longitude: 78.3772),
  ],
);

Future<void> openDestination(WidgetTester tester) async {
  final start = find.text('Start journey');
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const Key('destination_search_field')),
    query,
  );
  final button = find.byKey(const Key('search_places_button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> selectHitech(WidgetTester tester) async {
  await search(tester, 'Hitech');
  final result = find.byKey(const Key('place_result_0'));
  await tester.ensureVisible(result);
  await tester.tap(result);
  await tester.pump();
}

Future<void> confirm(WidgetTester tester) async {
  final button = find.byKey(const Key('confirm_destination_button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

void main() {
  test('active journey survives repository recreation with its start details', () async {
    SharedPreferences.setMockInitialValues({});
    final startedAt = DateTime.utc(2026, 10, 12, 9);
    final journey = ActiveJourney(
      startingLocation: _start,
      currentLocation: _update,
      destination: _hitech,
      startedAt: startedAt,
      arrivalAlertTriggered: true,
    );

    await SharedPreferencesActiveJourneyRepository().saveActiveJourney(journey);
    final restored = await SharedPreferencesActiveJourneyRepository()
        .loadActiveJourney();

    expect(restored?.destination.name, _hitech.name);
    expect(restored?.startingLocation.latitude, _start.latitude);
    expect(restored?.currentLocation.latitude, _update.latitude);
    expect(restored?.startedAt, startedAt);
    expect(restored?.arrivalAlertTriggered, isTrue);
  });

  test('arrival proximity uses the 500 metre radius', () {
    final inside = CurrentLocation(
      latitude: _hitech.latitude + 0.001,
      longitude: _hitech.longitude,
      timestamp: _start.timestamp,
    );
    final outside = CurrentLocation(
      latitude: _hitech.latitude + 0.006,
      longitude: _hitech.longitude,
      timestamp: _start.timestamp,
    );

    expect(distanceToDestinationMeters(inside, _hitech), lessThan(500));
    expect(distanceToDestinationMeters(outside, _hitech), greaterThan(500));
  });

  testWidgets('arrival alert triggers once and remains triggered after restart', (
    tester,
  ) async {
    final locations = StreamController<CurrentLocation>.broadcast(sync: true);
    final service = FakeLocationService(
      Future.value(LocationResult.success(_start)),
      stream: locations.stream,
    );
    final repository = InMemoryActiveJourneyRepository();
    final notifier = FakeArrivalAlertNotifier();
    final routes = FakeRouteService((_, _) async => _route);
    await pumpApp(
      tester,
      service,
      successfulSearch(),
      routeService: routes,
      activeJourneyRepository: repository,
      arrivalAlertNotifier: notifier,
    );
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);

    locations.add(_start);
    await tester.pump();
    expect(notifier.calls, 0);
    final near = CurrentLocation(
      latitude: _hitech.latitude + 0.001,
      longitude: _hitech.longitude,
      timestamp: _update.timestamp,
    );
    locations.add(near);
    await tester.pump();
    await tester.pump();
    expect(find.text('Your stop is approaching!'), findsOneWidget);
    expect(notifier.calls, 1);
    expect((await repository.loadActiveJourney())?.arrivalAlertTriggered, isTrue);

    locations.add(near);
    await tester.pump();
    expect(notifier.calls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(
      tester,
      FakeLocationService(
        Future.value(LocationResult.success(near)),
        stream: locations.stream,
      ),
      successfulSearch(),
      routeService: routes,
      activeJourneyRepository: repository,
      arrivalAlertNotifier: notifier,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    locations.add(near);
    await tester.pump();
    expect(notifier.calls, 1);
    expect(find.text('Your stop is approaching!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await locations.close();
  });

  test('invalid saved active journey is discarded safely', () async {
    SharedPreferences.setMockInitialValues({
      'arrivio_active_journey': '{not valid json',
    });

    expect(
      await SharedPreferencesActiveJourneyRepository().loadActiveJourney(),
      isNull,
    );
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'arrivio_active_journey',
      ),
      isFalse,
    );
  });

  testWidgets('saved active journey restores only after GPS and route recover', (
    tester,
  ) async {
    final startedAt = DateTime.utc(2026, 10, 12, 9);
    final repository = InMemoryActiveJourneyRepository(
      journey: ActiveJourney(
        startingLocation: _start,
        currentLocation: _update,
        destination: _hitech,
        startedAt: startedAt,
      ),
    );
    final location = FakeLocationService(
      Future.value(LocationResult.success(_update)),
    );
    final routes = FakeRouteService((_, _) async => _route);

    await pumpApp(
      tester,
      location,
      successfulSearch(),
      routeService: routes,
      activeJourneyRepository: repository,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Live Journey'), findsOneWidget);
    expect(find.text(_hitech.name), findsWidgets);
    expect(location.watchCalls, 1);
    expect(routes.calls, 1);
    expect((await repository.loadActiveJourney())?.startedAt, startedAt);
  });

  testWidgets('saved journey waits when GPS permission or fix is unavailable', (
    tester,
  ) async {
    final repository = InMemoryActiveJourneyRepository(
      journey: ActiveJourney(
        startingLocation: _start,
        currentLocation: _start,
        destination: _hitech,
        startedAt: DateTime.utc(2026, 10, 12, 9),
      ),
    );
    final location = FakeLocationService(
      Future.value(
        const LocationResult.failure(
          LocationFailure.permissionDenied,
          'Location permission is needed.',
        ),
      ),
    );
    final routes = FakeRouteService((_, _) async => _route);

    await pumpApp(
      tester,
      location,
      successfulSearch(),
      routeService: routes,
      activeJourneyRepository: repository,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Live Journey'), findsNothing);
    expect(location.watchCalls, 0);
    expect(routes.calls, 0);
    expect(await repository.loadActiveJourney(), isNotNull);
  });

  test('journey history survives repository recreation and keeps its status', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SharedPreferencesJourneyHistoryRepository();
    final startedAt = DateTime.utc(2026, 10, 12, 9);
    final completed = JourneyHistoryEntry(
      destination: 'Hitech City',
      startedAt: startedAt,
      endedAt: DateTime.utc(2026, 10, 12, 9, 30),
      status: JourneyHistoryStatus.completed,
    );
    final cancelled = JourneyHistoryEntry(
      destination: 'Railway Station',
      startedAt: startedAt,
      endedAt: DateTime.utc(2026, 10, 12, 9, 10),
      status: JourneyHistoryStatus.cancelled,
    );

    await repository.addJourney(completed);
    await repository.addJourney(cancelled);
    final restored = await SharedPreferencesJourneyHistoryRepository()
        .getHistory();

    expect(
      restored.map((entry) => entry.destination),
      ['Railway Station', 'Hitech City'],
    );
    expect(
      restored.map((entry) => entry.status),
      [JourneyHistoryStatus.cancelled, JourneyHistoryStatus.completed],
    );
    expect(restored.first.startedAt, startedAt);
    expect(restored.first.endedAt, cancelled.endedAt);
  });

  testWidgets('Journeys tab shows a friendly empty history state', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeLocationService(Future.value(LocationResult.success(_start))),
      successfulSearch(),
    );
    await tester.tap(find.text('Journeys'));
    await tester.pump();
    expect(find.text('Journey history'), findsOneWidget);
    expect(find.text('No journeys yet'), findsOneWidget);
  });

  test('MapTiler config preserves its compile-time key value', () {
    final key = MapTilerConfig.apiKey;
    expect(MapTilerConfig.isConfigured, key.isNotEmpty);
    expect(MapTilerConfig.rasterTileUrl, contains('key=$key'));
  });

  test(
    'route metrics format distance and estimated arrival professionally',
    () {
      expect(formatRouteDistance(850), '850 m');
      expect(formatRouteDistance(2450), '2.5 km');
      expect(formatEstimatedArrival(DateTime(2026, 1, 1, 10), 900), '10:15 AM');
      expect(_route.geometry.first.latitude, _start.latitude);
      expect(_route.geometry.first.longitude, _start.longitude);
      expect(_route.geometry.last.latitude, _hitech.latitude);
      expect(_route.geometry.last.longitude, _hitech.longitude);
    },
  );

  testWidgets('profile button opens saved user profile', (tester) async {
    await tester.pumpWidget(
      ArrivioApp(
        onboardingRepository: InMemoryOnboardingRepository(
          completed: true,
          profile: const OnboardingProfile(
            fullName: 'Taylor Lee',
            contact: 'taylor@example.com',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.byKey(const Key('profile_button')));
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Taylor Lee'), findsOneWidget);
  });

  testWidgets('editing profile updates persistence and home greeting', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository(
      completed: true,
      profile: const OnboardingProfile(
        fullName: 'Taylor Lee',
        contact: 'taylor@example.com',
      ),
    );
    await tester.pumpWidget(ArrivioApp(onboardingRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Morgan Patel');
    await tester.enterText(find.byType(TextField).at(1), 'morgan@example.com');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(repository.profile?.fullName, 'Morgan Patel');
    expect(find.text('Good morning, Morgan Patel'), findsOneWidget);
  });

  testWidgets('sign out clears local session and returns to welcome', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository(completed: true);
    await tester.pumpWidget(ArrivioApp(onboardingRepository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(repository.completed, isFalse);
    expect(find.text('Welcome to ArrivioAI'), findsOneWidget);
  });

  testWidgets('new user completes onboarding and opens dashboard', (
    tester,
  ) async {
    final repository = InMemoryOnboardingRepository();
    await tester.pumpWidget(ArrivioApp(onboardingRepository: repository));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'alex@example.com');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alex Morgan');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final finish = find.widgetWithText(ElevatedButton, 'Finish setup');
    await tester.scrollUntilVisible(finish, 120);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(repository.completed, isTrue);
    expect(find.text('Good morning, Alex Morgan'), findsOneWidget);
  });

  testWidgets('development reset returns a completed user to onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      ArrivioApp(
        onboardingRepository: InMemoryOnboardingRepository(completed: true),
        resetOnboardingOnLaunch: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to ArrivioAI'), findsOneWidget);
  });

  testWidgets(
    'destination screen loads and confirm is disabled before selection',
    (tester) async {
      await pumpApp(
        tester,
        FakeLocationService(Future.value(LocationResult.success(_start))),
        successfulSearch(),
      );
      await openDestination(tester);
      expect(find.text('Choose Destination'), findsOneWidget);
      expect(find.textContaining('Current location: 17.3850'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('confirm_destination_button')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('destination search shows loading then deterministic results', (
    tester,
  ) async {
    final results = Completer<List<Destination>>();
    final fake = FakePlaceSearchService((_) => results.future);
    await pumpApp(
      tester,
      FakeLocationService(Future.value(LocationResult.success(_start))),
      fake,
    );
    await openDestination(tester);
    await tester.enterText(
      find.byKey(const Key('destination_search_field')),
      'Hitech',
    );
    await tester.tap(find.byKey(const Key('search_places_button')));
    await tester.pump();
    expect(find.byKey(const Key('place_search_loading_state')), findsOneWidget);
    results.complete(const [_hitech]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(_hitech.name), findsOneWidget);
    expect(find.text(_hitech.address), findsOneWidget);
    expect(fake.queries, ['Hitech']);
  });

  testWidgets('destination search shows empty and error states then retries', (
    tester,
  ) async {
    var attempts = 0;
    final fake = FakePlaceSearchService((_) async {
      attempts++;
      if (attempts == 1) {
        return const [];
      }
      if (attempts == 2) {
        throw const PlaceSearchException('Search is unavailable.');
      }
      return const [_hitech];
    });
    await pumpApp(
      tester,
      FakeLocationService(Future.value(LocationResult.success(_start))),
      fake,
    );
    await openDestination(tester);
    await search(tester, 'Hitech');
    expect(
      find.text('No places found. Try a different search.'),
      findsOneWidget,
    );
    final retry = find.text('Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Search is unavailable.'), findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(_hitech.name), findsOneWidget);
    expect(attempts, 3);
  });

  testWidgets(
    'selecting a result enables confirm and passes it into live journey',
    (tester) async {
      await pumpApp(
        tester,
        FakeLocationService(Future.value(LocationResult.success(_start))),
        successfulSearch(),
      );
      await openDestination(tester);
      await selectHitech(tester);
      expect(find.text(_hitech.name), findsWidgets);
      expect(find.text(_hitech.address), findsWidgets);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const Key('confirm_destination_button')),
            )
            .onPressed,
        isNotNull,
      );
      await confirm(tester);
      expect(find.text('Live Journey'), findsOneWidget);
      expect(find.text(_hitech.name), findsWidgets);
    },
  );

  testWidgets('selected destination retains expected latitude and longitude', (
    tester,
  ) async {
    Destination? selected;
    CurrentLocation? location;
    await tester.pumpWidget(
      MaterialApp(
        home: DestinationScreen(
          onBack: () {},
          onConfirm: (d, l) {
            selected = d;
            location = l;
          },
          locationService: FakeLocationService(
            Future.value(LocationResult.success(_start)),
          ),
          placeSearchService: successfulSearch(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await selectHitech(tester);
    final button = find.byKey(const Key('confirm_destination_button'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(selected, _hitech);
    expect(location, _start);
  });

  testWidgets('choose destination shows loading while GPS resolves', (
    tester,
  ) async {
    final completer = Completer<LocationResult>();
    await pumpApp(
      tester,
      FakeLocationService(completer.future),
      successfulSearch(),
    );
    await openDestination(tester);
    expect(find.byKey(const Key('location_loading_state')), findsOneWidget);
    completer.complete(LocationResult.success(_start));
    await tester.pump();
    expect(find.byKey(const Key('location_loading_state')), findsNothing);
  });

  testWidgets('permission denial is explained', (tester) async {
    await pumpApp(
      tester,
      FakeLocationService(
        Future.value(
          const LocationResult.failure(
            LocationFailure.permissionDenied,
            'Location permission is needed.',
          ),
        ),
      ),
      successfulSearch(),
    );
    await openDestination(tester);
    expect(find.byKey(const Key('location_error_state')), findsOneWidget);
    expect(find.text('No GPS fix · no fallback location'), findsOneWidget);
  });

  testWidgets(
    'live journey streams current location without changing start or destination',
    (tester) async {
      final updates = StreamController<CurrentLocation>.broadcast(sync: true);
      final service = FakeLocationService(
        Future.value(LocationResult.success(_start)),
        stream: updates.stream,
      );
      final history = InMemoryJourneyHistoryRepository();
      final activeJourney = InMemoryActiveJourneyRepository();
      await pumpApp(
        tester,
        service,
        successfulSearch(),
        historyRepository: history,
        activeJourneyRepository: activeJourney,
      );
      await openDestination(tester);
      await selectHitech(tester);
      await confirm(tester);
      expect(find.text('Live Journey'), findsOneWidget);
      expect(service.watchCalls, 1);
      updates.add(_update);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final progressLive = find.text(
        'Live location updates are being received.',
      );
      await tester.scrollUntilVisible(progressLive, 180);
      expect(progressLive, findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('17.40000, 78.50000'),
        180,
      );
      expect(find.text('Live'), findsOneWidget);
      expect(find.textContaining('17.40000, 78.50000'), findsWidgets);
      expect(find.textContaining('17.38500, 78.48670'), findsWidgets);
      expect(find.text(_hitech.name), findsWidgets);
      expect(service.watchCalls, 1);
      final cancel = find.byKey(const Key('cancel_journey_button'));
      final finish = find.byKey(const Key('finish_journey_button'));
      expect(cancel, findsOneWidget);
      expect(finish, findsOneWidget);
      await tester.tap(cancel);
      await pumpDialogTransition(tester);
      expect(find.text('Cancel this journey?'), findsOneWidget);
      expect(service.activeWatchers, 1);
      await tester.tap(find.text('Keep journey'));
      await pumpDialogTransition(tester);
      expect(find.text('Live Journey'), findsOneWidget);
      await tester.tap(cancel);
      await pumpDialogTransition(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel journey'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Start journey'), findsOneWidget);
      expect(service.activeWatchers, 0);
      expect(await activeJourney.loadActiveJourney(), isNull);
      final saved = await history.getHistory();
      expect(saved.single.status, JourneyHistoryStatus.cancelled);
      await tester.tap(find.text('Journeys'));
      await tester.pump();
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text(_hitech.name), findsOneWidget);
      expect(find.textContaining('Started:'), findsOneWidget);
      expect(find.textContaining('Ended:'), findsOneWidget);
      await updates.close();
    },
  );

  testWidgets('live location stream errors leave journey open', (tester) async {
    final service = FakeLocationService(
      Future.value(LocationResult.success(_start)),
      watchStreams: [
        Stream<CurrentLocation>.error(
          const LocationTrackingException(
            LocationFailure.unavailable,
            'Live location is temporarily unavailable. We will keep your journey open.',
          ),
        ),
      ],
    );
    await pumpApp(tester, service, successfulSearch());
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);
    expect(find.text('Live Journey'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    final message = find.text(
      'Live location is temporarily unavailable. We will keep your journey open.',
    );
    await tester.scrollUntilVisible(message, 240);
    expect(message, findsOneWidget);
    expect(find.byKey(const Key('retry_tracking_button')), findsOneWidget);
    final pausedProgress = find.text(
      'Progress is paused while live location is unavailable.',
    );
    await tester.scrollUntilVisible(pausedProgress, 180);
    expect(find.text('Live Journey'), findsOneWidget);
    expect(pausedProgress, findsOneWidget);
  });

  testWidgets('finishing a journey clears it and stops location tracking', (
    tester,
  ) async {
    final updates = StreamController<CurrentLocation>.broadcast(sync: true);
    final service = FakeLocationService(
      Future.value(LocationResult.success(_start)),
      stream: updates.stream,
    );
    final history = InMemoryJourneyHistoryRepository();
    final activeJourney = InMemoryActiveJourneyRepository();
    await pumpApp(
      tester,
      service,
      successfulSearch(),
      historyRepository: history,
      activeJourneyRepository: activeJourney,
    );
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);
    expect(service.activeWatchers, 1);

    final finish = find.byKey(const Key('finish_journey_button'));
    expect(finish, findsOneWidget);
    await tester.tap(finish);
    await tester.pump();

    expect(find.text('Start journey'), findsOneWidget);
    expect(find.text('You have arrived'), findsNothing);
    expect(service.activeWatchers, 0);
    expect(await activeJourney.loadActiveJourney(), isNull);
    final saved = await history.getHistory();
    expect(saved.single.status, JourneyHistoryStatus.completed);
    await tester.tap(find.text('Journeys'));
    await tester.pump();
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text(_hitech.name), findsOneWidget);
    expect(find.textContaining('Started:'), findsOneWidget);
    expect(find.textContaining('Ended:'), findsOneWidget);
    await updates.close();
  });

  testWidgets('arrival preview returns to the active journey without finishing', (
    tester,
  ) async {
    final updates = StreamController<CurrentLocation>.broadcast(sync: true);
    final history = InMemoryJourneyHistoryRepository();
    final activeJourney = InMemoryActiveJourneyRepository();
    final notifier = FakeArrivalAlertNotifier();
    final service = FakeLocationService(
      Future.value(LocationResult.success(_start)),
      stream: updates.stream,
    );
    await pumpApp(
      tester,
      service,
      successfulSearch(),
      historyRepository: history,
      activeJourneyRepository: activeJourney,
      arrivalAlertNotifier: notifier,
    );
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);

    final preview = find.text('Preview destination reached');
    await tester.scrollUntilVisible(
      preview,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(preview);
    await tester.pump();
    expect(find.text('You have arrived'), findsOneWidget);
    expect(find.textContaining('Preview state'), findsOneWidget);
    updates.add(
      CurrentLocation(
        latitude: _hitech.latitude + 0.001,
        longitude: _hitech.longitude,
        timestamp: _update.timestamp,
      ),
    );
    await tester.pump();
    expect(notifier.calls, 0);
    expect((await activeJourney.loadActiveJourney())?.arrivalAlertTriggered, isFalse);

    await tester.tap(find.text('Back to journey'));
    await tester.pump();
    expect(find.text('Live Journey'), findsOneWidget);
    expect(service.watchCalls, 2);
    expect(await history.getHistory(), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(service.activeWatchers, 0);
    await updates.close();
  });

  testWidgets('retry replaces tracking and disposal cancels the subscription', (
    tester,
  ) async {
    final updates = StreamController<CurrentLocation>.broadcast(sync: true);
    final service = FakeLocationService(
      Future.value(LocationResult.success(_start)),
      watchStreams: [
        Stream<CurrentLocation>.error(
          const LocationTrackingException(
            LocationFailure.unavailable,
            'Live location is temporarily unavailable. We will keep your journey open.',
          ),
        ),
        updates.stream,
      ],
    );
    await pumpApp(tester, service, successfulSearch());
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);
    expect(find.text('Live Journey'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    final retry = find.byKey(const Key('retry_tracking_button'));
    await tester.scrollUntilVisible(retry, 240);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(service.watchCalls, 2);
    expect(service.activeWatchers, 1);
    await tester.tap(find.byTooltip('Cancel journey'));
    await pumpDialogTransition(tester);
    await tester.tap(find.text('Keep journey'));
    await pumpDialogTransition(tester);
    expect(find.text('Live Journey'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel journey'));
    await pumpDialogTransition(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel journey'),
      ),
    );
    await tester.pump();
    expect(find.text('Start journey'), findsOneWidget);
    expect(service.activeWatchers, 0);
    await updates.close();
  });

  testWidgets(
    'loads and displays the initial ORS route without rerouting GPS',
    (tester) async {
      final updates = StreamController<CurrentLocation>.broadcast(sync: true);
      final routes = FakeRouteService((_, _) async => _route);
      await pumpApp(
        tester,
        FakeLocationService(
          Future.value(LocationResult.success(_start)),
          stream: updates.stream,
        ),
        successfulSearch(),
        routeService: routes,
      );
      await openDestination(tester);
      await selectHitech(tester);
      await confirm(tester);
      expect(find.byKey(const Key('route_loading_state')), findsOneWidget);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('2.5 km'), 180);
      expect(find.text('2.5 km'), findsOneWidget);
      expect(routes.calls, 1);
      updates.add(_update);
      await tester.pump();
      expect(routes.calls, 1);
      await updates.close();
    },
  );

  testWidgets('route failure shows retry and retries only the route', (
    tester,
  ) async {
    var attempts = 0;
    final routes = FakeRouteService((_, _) async {
      attempts++;
      if (attempts == 1) {
        throw const RouteServiceException('Route unavailable.');
      }
      return _route;
    });
    await pumpApp(
      tester,
      FakeLocationService(Future.value(LocationResult.success(_start))),
      successfulSearch(),
      routeService: routes,
    );
    await openDestination(tester);
    await selectHitech(tester);
    await confirm(tester);
    await tester.pump();
    expect(find.byKey(const Key('route_error_state')), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry_route_button')));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('2.5 km'), 180);
    expect(find.text('2.5 km'), findsOneWidget);
    expect(routes.calls, 2);
  });
}
