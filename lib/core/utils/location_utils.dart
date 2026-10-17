import 'package:geolocator/geolocator.dart';

import 'location_storage.dart';

class LocationUtils {
  static Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  static Future<Position?> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return null;
      }
    } else if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await LocationStorage.save(position);
      return position;
    } catch (_) {
      return null;
    }
  }

  /// Current GPS fix, or last saved coordinates.
  static Future<Position?> getEffectivePosition() async {
    final current = await getCurrentPosition();
    if (current != null) return current;
    return LocationStorage.load();
  }

  static Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  static Future<void> openAppSettings() => Geolocator.openAppSettings();
}
