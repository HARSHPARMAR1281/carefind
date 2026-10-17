import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's last known coordinates for offline / permission-denied fallback.
class LocationStorage {
  static const _latKey = 'carefind_last_lat';
  static const _lngKey = 'carefind_last_lng';
  static const _timeKey = 'carefind_last_location_time';

  static Future<void> save(Position position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, position.latitude);
    await prefs.setDouble(_lngKey, position.longitude);
    await prefs.setInt(_timeKey, position.timestamp.millisecondsSinceEpoch);
  }

  static Future<Position?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;

    final timeMs = prefs.getInt(_timeKey);
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: timeMs != null
          ? DateTime.fromMillisecondsSinceEpoch(timeMs)
          : DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
