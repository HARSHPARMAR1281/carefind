import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/hospital_provider.dart';
import '../screens/hospital_detail_screen.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final position = provider.position;

    if (position == null || provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (AppConfig.googleMapsApiKey.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.map, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Maps require GOOGLE_MAPS_API_KEY',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Run: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '${provider.nearby.length} hospitals loaded in list view',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final userLatLng = LatLng(position.latitude, position.longitude);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('user'),
        position: userLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You'),
      ),
      ...provider.nearby.map((h) {
        return Marker(
          markerId: MarkerId(h.id),
          position: LatLng(h.latitude, h.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            h.emergencyAvailable
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: h.name,
            snippet: h.distanceKm != null ? '${h.distanceKm} km away' : null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HospitalDetailScreen(hospitalId: h.id),
              ),
            ),
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospitalId: h.id),
            ),
          ),
        );
      }),
    };

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: userLatLng, zoom: 13),
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      onMapCreated: (controller) => _mapController = controller,
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
