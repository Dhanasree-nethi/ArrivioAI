import 'dart:async';

import 'package:flutter/material.dart';
import '../models/current_location.dart';
import '../models/destination.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../widgets/map_preview.dart';

class DestinationScreen extends StatefulWidget {
  const DestinationScreen({
    super.key,
    required this.onBack,
    required this.onConfirm,
    required this.locationService,
    required this.placeSearchService,
  });
  final VoidCallback onBack;
  final FutureOr<void> Function(Destination, CurrentLocation) onConfirm;
  final LocationService locationService;
  final PlaceSearchService placeSearchService;
  @override
  State<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends State<DestinationScreen> {
  final c = TextEditingController();
  Destination? selected;
  CurrentLocation? location;
  LocationResult? result;
  List<Destination> places = [];
  String? message;
  bool locating = true, searching = false;
  bool confirming = false;
  int request = 0;

  Future<void> _confirmDestination() async {
    final destination = selected;
    final currentLocation = location;
    if (destination == null || currentLocation == null || confirming) return;
    setState(() => confirming = true);
    try {
      await widget.onConfirm(destination, currentLocation);
      if (mounted) setState(() => confirming = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          confirming = false;
          message = 'We could not save this journey. Please try again.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  Future<void> getLocation() async {
    setState(() => locating = true);
    final r = await widget.locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        locating = false;
        result = r;
        location = r.location;
      });
    }
  }

  Future<void> search() async {
    final q = c.text.trim();
    if (q.length < 2) {
      setState(
        () => message = q.isEmpty
            ? 'Enter a destination to search.'
            : 'Enter at least two characters.',
      );
      return;
    }
    final id = ++request;
    setState(() {
      searching = true;
      message = null;
      places = [];
    });
    try {
      final r = await widget.placeSearchService.searchPlaces(q, near: location);
      if (mounted && id == request) {
        setState(() {
          searching = false;
          places = r;
          message = r.isEmpty
              ? 'No places found. Try a different search.'
              : null;
        });
      }
    } on PlaceSearchException catch (e) {
      if (mounted && id == request) {
        setState(() {
          searching = false;
          message = e.message;
        });
      }
    }
  }

  @override
  void dispose() {
    request++;
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext x) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        onPressed: widget.onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Choose Destination'),
    ),
    body: SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  key: const Key('destination_search_field'),
                  controller: c,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => search(),
                  decoration: InputDecoration(
                    hintText: 'Search for a real place',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      key: const Key('search_places_button'),
                      tooltip: 'Search places',
                      onPressed: searching ? null : search,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MapPreview(
                  destination: selected,
                  currentLocation: location,
                  compact: true,
                ),
                if (location != null)
                  Tooltip(
                    message:
                        'Using device GPS. On an emulator, configure its location in Extended Controls before starting.',
                    child: Text(
                      'Current location: ${location!.latitude.toStringAsFixed(4)}, ${location!.longitude.toStringAsFixed(4)}',
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: content(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected?.name ?? 'Select a destination'),
                if (selected != null)
                  Text(
                    selected!.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('confirm_destination_button'),
                    onPressed:
                        selected == null || location == null || confirming
                        ? null
                        : _confirmDestination,
                    child: Text(
                      confirming ? 'Saving journey…' : 'Confirm Destination',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  Widget content() {
    if (locating) {
      return const Center(
        child: CircularProgressIndicator(key: Key('location_loading_state')),
      );
    }
    if (location == null) {
      return Center(
        key: const Key('location_error_state'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No GPS fix · no fallback location'),
            Text(result?.message ?? ''),
            TextButton(onPressed: getLocation, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (searching) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('place_search_loading_state'),
        ),
      );
    }
    if (message != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message!, textAlign: TextAlign.center),
            TextButton(onPressed: search, child: const Text('Try again')),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: places.length,
      itemBuilder: (_, i) {
        final p = places[i];
        return ListTile(
          key: Key('place_result_$i'),
          leading: const Icon(Icons.place_rounded),
          title: Text(p.name),
          subtitle: Text(p.address),
          onTap: () => setState(() => selected = p),
        );
      },
    );
  }
}
