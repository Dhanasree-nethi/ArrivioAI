# mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# ArrivioAI

This prototype keeps onboarding state locally with `shared_preferences` and
uses foreground GPS while a live journey is open. After a successful setup,
returning users open the dashboard directly.

To repeat onboarding in a development build, launch with:

```sh
flutter run --dart-define=ARRIVIO_RESET_ONBOARDING=true
```

## MapTiler for local Android development

Map tiles and real place search use the compile-time `MAPTILER_API_KEY`
define. Do not add the key to Dart files, project configuration, or version
control. Supply it only when launching a local build:

```sh
flutter run -d emulator-5554 --dart-define=MAPTILER_API_KEY=MY_KEY
```

Replace `MY_KEY` in your local terminal command with your MapTiler key. When
the define is absent, the app intentionally shows its existing **Map setup
needed** state and place search explains that the key must be configured.
Widget tests inject `FakePlaceSearchService` and never use this key or call
MapTiler.

## OpenRouteService routing

Road routing, distance, and estimated arrival use OpenRouteService's current
Directions API at `https://api.heigit.org`. Configure the compile-time
`OPENROUTESERVICE_API_KEY` define locally. Never put either API key in source,
project configuration, or version control.

```sh
flutter run -d emulator-5554 --dart-define=MAPTILER_API_KEY=MY_MAPTILER_KEY --dart-define=OPENROUTESERVICE_API_KEY=MY_ORS_KEY
```

MapTiler remains responsible for tiles and place search; Geolocator remains
responsible for foreground GPS. Tests inject a fake route service and never
make real routing requests.

### Android emulator location

The Android emulator can report its default virtual location (Mountain View)
as a valid GPS fix. ArrivioAI uses the location Geolocator reports and does not
substitute a hard-coded fallback. Before starting a journey, open the
emulator's **Extended Controls → Location**, choose or enter the desired
coordinates, and apply/send the location. Then return to the app and start the
journey so the initial route uses that fix. If no GPS fix is available, the app
keeps the journey start unset and explains that no fallback location is used.
