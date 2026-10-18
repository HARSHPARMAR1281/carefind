import 'package:geolocator/geolocator.dart';

/// Why location is, or is not, available right now.
enum LocationAccess {
  /// Permission given and GPS is on.
  granted,

  /// Permission not given yet (or refused once); the system dialog can still
  /// be shown.
  denied,

  /// Refused with "don't ask again"; only the app settings can change it.
  deniedForever,

  /// Permission is fine but the phone's location/GPS switch is off.
  serviceOff,
}

class PermissionUtils {
  /// Current state, without showing any dialog.
  static Future<LocationAccess> locationAccess() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      return LocationAccess.denied;
    }
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    return serviceOn ? LocationAccess.granted : LocationAccess.serviceOff;
  }

  /// Shows the system "Allow location?" dialog if permission is still
  /// undecided, then reports the resulting state.
  static Future<LocationAccess> requestLocationAccess() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    return locationAccess();
  }

  static Future<bool> requestLocationPermission() async {
    final access = await requestLocationAccess();
    return access == LocationAccess.granted ||
        access == LocationAccess.serviceOff;
  }

  static Future<bool> isLocationGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
