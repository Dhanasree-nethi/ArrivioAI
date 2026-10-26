import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/current_location.dart';
import '../models/destination.dart';
import '../models/route.dart';
import '../services/map_tiler_config.dart';
import '../theme/app_theme.dart';

/// A real, pan-and-zoom map backed by MapTiler raster tiles.
class MapPreview extends StatefulWidget {
  const MapPreview({
    super.key,
    this.destination,
    this.currentLocation,
    this.startingLocation,
    this.route,
    this.compact = false,
  });

  final Destination? destination;
  final CurrentLocation? currentLocation;
  final CurrentLocation? startingLocation;
  final JourneyRoute? route;
  final bool compact;

  @override
  State<MapPreview> createState() => _MapPreviewState();
}

class _MapPreviewState extends State<MapPreview> {
  final _mapController = MapController();
  bool _mapReady = false;

  LatLng get _fallbackCenter => const LatLng(20.5937, 78.9629);

  @override
  void didUpdateWidget(covariant MapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.destination != oldWidget.destination ||
        widget.startingLocation != oldWidget.startingLocation ||
        widget.route != oldWidget.route) {
      _fitRelevantPoints();
    }
  }

  void _fitRelevantPoints() {
    if (!_mapReady) return;
    final points = <LatLng>[
      if (widget.route != null)
        ...widget.route!.geometry.map(
          (coordinate) => LatLng(coordinate.latitude, coordinate.longitude),
        ),
      if (widget.startingLocation != null)
        LatLng(
          widget.startingLocation!.latitude,
          widget.startingLocation!.longitude,
        ),
      if (widget.destination != null)
        LatLng(widget.destination!.latitude, widget.destination!.longitude),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.single, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(52),
        maxZoom: 15,
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 220.0 : 300.0;
    if (!MapTilerConfig.isConfigured) {
      return _MapConfigurationCard(height: height);
    }

    final initialCenter = widget.currentLocation == null
        ? _fallbackCenter
        : LatLng(
            widget.currentLocation!.latitude,
            widget.currentLocation!.longitude,
          );
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: widget.currentLocation == null ? 4.5 : 15,
                onMapReady: () {
                  _mapReady = true;
                  _fitRelevantPoints();
                },
              ),
              children: [
                TileLayer(urlTemplate: MapTilerConfig.rasterTileUrl),
                if (widget.route != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.route!.geometry
                            .map(
                              (point) =>
                                  LatLng(point.latitude, point.longitude),
                            )
                            .toList(growable: false),
                        color: AppTheme.blue,
                        strokeWidth: 5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _markers()),
                RichAttributionWidget(
                  attributions: const [
                    TextSourceAttribution(
                      '© MapTiler © OpenStreetMap contributors',
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 36,
              child: Material(
                color: Colors.white,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  key: const Key('recenter_map_button'),
                  tooltip: 'Recenter on current location',
                  onPressed: widget.currentLocation == null
                      ? null
                      : () => _mapController.move(
                          LatLng(
                            widget.currentLocation!.latitude,
                            widget.currentLocation!.longitude,
                          ),
                          15,
                        ),
                  icon: const Icon(
                    Icons.my_location_rounded,
                    color: AppTheme.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _markers() => [
    if (widget.startingLocation != null)
      Marker(
        point: LatLng(
          widget.startingLocation!.latitude,
          widget.startingLocation!.longitude,
        ),
        width: 54,
        height: 54,
        child: const _MapMarker(
          icon: Icons.trip_origin_rounded,
          color: Color(0xFF067647),
          tooltip: 'Starting location',
        ),
      ),
    if (widget.currentLocation != null)
      Marker(
        point: LatLng(
          widget.currentLocation!.latitude,
          widget.currentLocation!.longitude,
        ),
        width: 54,
        height: 54,
        child: const _MapMarker(
          icon: Icons.my_location_rounded,
          color: AppTheme.blue,
          tooltip: 'Current location',
        ),
      ),
    if (widget.destination != null)
      Marker(
        point: LatLng(
          widget.destination!.latitude,
          widget.destination!.longitude,
        ),
        width: 54,
        height: 54,
        child: const _MapMarker(
          icon: Icons.location_on_rounded,
          color: Color(0xFFE45B4F),
          tooltip: 'Selected destination',
        ),
      ),
  ];
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.icon,
    required this.color,
    required this.tooltip,
  });
  final IconData icon;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 25),
    ),
  );
}

class _MapConfigurationCard extends StatelessWidget {
  const _MapConfigurationCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('map_configuration_state'),
    height: height,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppTheme.mist,
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.map_outlined, color: AppTheme.blue, size: 34),
        SizedBox(height: 12),
        Text('Map setup needed', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 5),
        Text(
          'Add MAPTILER_API_KEY to display the interactive map and search real places.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.mutedInk),
        ),
      ],
    ),
  );
}
