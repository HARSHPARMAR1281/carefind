import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/models/hospital.dart';
import '../data/models/map_mode.dart';
import '../providers/hospital_provider.dart';
import '../screens/hospital_detail_screen.dart';

/// Interactive map built on OpenStreetMap tiles (flutter_map).
///
/// Hospitals come from Overpass / Nominatim, routes come from OSRM — all
/// exposed through [HospitalProvider]. No API key is required.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _controller = MapController();
  bool _mapReady = false;
  String? _appliedCameraKey;
  Hospital? _selected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _cameraKey(MapDisplayState s) =>
      '${s.mode.name}|${s.focusHospital?.id}|${s.routePoints.length}';

  void _applyCamera(MapDisplayState state, LatLng user) {
    final focus = state.focusHospital;
    if (state.routePoints.length >= 2) {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(state.routePoints),
          padding: const EdgeInsets.fromLTRB(48, 96, 48, 48),
        ),
      );
    } else if (focus != null) {
      _controller.move(LatLng(focus.latitude, focus.longitude), 15);
    } else {
      _controller.move(user, 13);
    }
  }

  /// Re-centres the camera only when the displayed state actually changed
  /// (new route, new focused hospital, back to nearby).
  void _scheduleCameraUpdate(MapDisplayState state, LatLng user) {
    final key = _cameraKey(state);
    if (!_mapReady || key == _appliedCameraKey) return;
    _appliedCameraKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyCamera(state, user);
    });
  }

  void _openDetails(Hospital h) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HospitalDetailScreen(hospitalId: h.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final position = provider.position;

    if (position == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final state = provider.mapState;
    final user = LatLng(position.latitude, position.longitude);
    final hospitals = provider.mapHospitals;
    final focus = state.focusHospital;

    _scheduleCameraUpdate(state, user);

    final markers = <Marker>[
      Marker(
        point: user,
        width: 28,
        height: 28,
        child: const _UserDot(),
      ),
      ...hospitals.map(
        (h) => Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 44,
          height: 44,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => setState(() => _selected = h),
            child: Icon(
              Icons.location_on,
              size: (focus?.id == h.id || _selected?.id == h.id) ? 44 : 36,
              color: h.emergencyAvailable
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ),
        ),
      ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: user,
            initialZoom: 13,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;
              _appliedCameraKey = _cameraKey(state);
              if (state.routePoints.isNotEmpty || state.focusHospital != null) {
                _applyCamera(state, user);
              }
            },
            onTap: (_, __) {
              if (_selected != null) setState(() => _selected = null);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: AppConfig.tilePackageName,
            ),
            if (state.routePoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: state.routePoints,
                    strokeWidth: 5,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            // Required by the OpenStreetMap tile usage policy / ODbL.
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (provider.loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
        if (state.mode == MapViewMode.directions &&
            state.routeDistanceKm != null)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _RouteBanner(
              hospitalName: focus?.name ?? 'Destination',
              distanceKm: state.routeDistanceKm!,
              minutes: state.routeDurationMinutes ?? 0,
              onClose: provider.showNearbyOnMap,
            ),
          ),
        Positioned(
          right: 12,
          bottom: _selected == null ? 28 : 128,
          child: FloatingActionButton.small(
            heroTag: 'map_recenter',
            tooltip: 'My location',
            onPressed: () => _controller.move(user, 14),
            child: const Icon(Icons.my_location),
          ),
        ),
        if (_selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _SelectedCard(
              hospital: _selected!,
              onDetails: () => _openDetails(_selected!),
              onDirections: () => provider.showDirectionsOnMap(_selected!),
            ),
          ),
      ],
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
      ),
    );
  }
}

class _RouteBanner extends StatelessWidget {
  const _RouteBanner({
    required this.hospitalName,
    required this.distanceKm,
    required this.minutes,
    required this.onClose,
  });

  final String hospitalName;
  final double distanceKm;
  final int minutes;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.directions_car),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hospitalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text('$distanceKm km  •  $minutes min drive'),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear route',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.hospital,
    required this.onDetails,
    required this.onDirections,
  });

  final Hospital hospital;
  final VoidCallback onDetails;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final distance = hospital.distanceKm;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hospital.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              [
                hospital.category,
                if (distance != null) '$distance km away',
                if (hospital.emergencyAvailable) 'Emergency',
              ].join('  •  '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onDetails,
                  child: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
