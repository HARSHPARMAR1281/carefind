/// App configuration. Pass overrides via --dart-define at build/run time.
class AppConfig {
  static const String appName = 'CareFind';
  static const String osmUserAgent = String.fromEnvironment(
    'OSM_USER_AGENT',
    defaultValue: 'CareFind/1.0 (https://github.com/carefind)',
  );
  static const String osmTileUrl = String.fromEnvironment(
    'OSM_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );
  static const String tilePackageName = 'com.example.carefind';
  static const String overpassApiUrl = String.fromEnvironment(
    'OVERPASS_API_URL',
    defaultValue: 'https://overpass-api.de/api/interpreter',
  );
  static const String nominatimApiUrl = String.fromEnvironment(
    'NOMINATIM_API_URL',
    defaultValue: 'https://nominatim.openstreetmap.org',
  );
  static const String osrmApiUrl = String.fromEnvironment(
    'OSRM_API_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static const double defaultSearchRadiusKm = 7.0;
  static const List<double> searchRadiusStepsKm = [7, 15, 25, 50, 100, 150];
  static const double maxSearchRadiusKm = 150;
  static const int minCategoryResults = 5;
  static const int minNearbyHospitals = 5;
  static const int targetNearbyHospitals = 20;

  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  /// Admin login (override via --dart-define in production).
  static const String adminId = String.fromEnvironment(
    'ADMIN_ID',
    defaultValue: 'admin',
  );
  static const String adminPassword = String.fromEnvironment(
    'ADMIN_PASSWORD',
    defaultValue: 'admin123',
  );
  static const String adminUserId = 'carefind_admin';
}
