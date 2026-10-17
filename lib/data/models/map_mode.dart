import 'package:latlong2/latlong.dart';

import 'hospital.dart';

enum MapViewMode {
  nearby,
  searchResult,
  directions,
}

class MapDisplayState {
  const MapDisplayState({
    this.mode = MapViewMode.nearby,
    this.focusHospital,
    this.searchResults = const [],
    this.routePoints = const [],
    this.routeDistanceKm,
    this.routeDurationMinutes,
  });

  final MapViewMode mode;
  final Hospital? focusHospital;
  final List<Hospital> searchResults;
  final List<LatLng> routePoints;
  final double? routeDistanceKm;
  final int? routeDurationMinutes;

  MapDisplayState copyWith({
    MapViewMode? mode,
    Hospital? focusHospital,
    List<Hospital>? searchResults,
    List<LatLng>? routePoints,
    double? routeDistanceKm,
    int? routeDurationMinutes,
    bool clearFocus = false,
    bool clearRoute = false,
  }) {
    return MapDisplayState(
      mode: mode ?? this.mode,
      focusHospital: clearFocus ? null : (focusHospital ?? this.focusHospital),
      searchResults: searchResults ?? this.searchResults,
      routePoints: clearRoute ? const [] : (routePoints ?? this.routePoints),
      routeDistanceKm: clearRoute ? null : (routeDistanceKm ?? this.routeDistanceKm),
      routeDurationMinutes:
          clearRoute ? null : (routeDurationMinutes ?? this.routeDurationMinutes),
    );
  }
}

class NearbyFetchResult {
  const NearbyFetchResult({
    required this.hospitals,
    required this.usedRadiusKm,
  });

  final List<Hospital> hospitals;
  final double usedRadiusKm;
}

class CategoryFetchResult {
  const CategoryFetchResult({
    required this.hospitals,
    required this.usedRadiusKm,
  });

  final List<Hospital> hospitals;
  final double usedRadiusKm;
}
