import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';
import '../core/utils/location_storage.dart';
import '../core/utils/location_utils.dart';
import '../core/utils/permission_utils.dart';
import '../data/models/hospital.dart';
import '../data/models/map_mode.dart';
import '../data/models/nearby_filters.dart';
import '../data/models/review.dart';
import '../data/repositories/hospital_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/routing_service.dart';

class HospitalProvider extends ChangeNotifier {
  HospitalProvider(this._hospitalRepo, this._userRepo);

  final HospitalRepository _hospitalRepo;
  final UserRepository _userRepo;
  final RoutingService _routing = const RoutingService();

  List<Hospital> _nearbyPool = [];
  List<Hospital> _nearby = [];
  List<Hospital> _globalSearchResults = [];
  List<Hospital> _nameSuggestions = [];
  List<Hospital> _favorites = [];
  List<Review> _reviews = [];
  Position? _position;
  bool _locationLive = false;
  bool _usingLastKnownLocation = false;
  bool _loadingNearby = false;
  bool _loadingGlobalSearch = false;
  bool _loadingRoute = false;
  String? _error;
  String _globalSearchQuery = '';
  String _searchPrefix = '';
  double _nearbyRadiusKm = AppConfig.defaultSearchRadiusKm;
  NearbyFilters _nearbyFilters = const NearbyFilters();
  MapDisplayState _mapState = const MapDisplayState();
  bool _openMapTabRequest = false;
  LocationAccess _locationAccess = LocationAccess.granted;
  bool _sortNearestFirst = true;
  DateTime? _lastRefreshAt;
  static const _staleAfter = Duration(minutes: 5);

  List<Hospital> get nearby => _nearby;
  List<Hospital> get nearbyPool => _nearbyPool;
  List<Hospital> get globalSearchResults => _globalSearchResults;
  List<Hospital> get nameSuggestions => _nameSuggestions;
  List<Hospital> get favorites => _favorites;
  List<Review> get reviews => _reviews;
  Position? get position => _position;
  bool get locationLive => _locationLive;
  bool get usingLastKnownLocation => _usingLastKnownLocation;
  bool get loadingNearby => _loadingNearby;
  bool get loadingGlobalSearch => _loadingGlobalSearch;
  bool get loadingRoute => _loadingRoute;
  bool get loading => _loadingNearby || _loadingGlobalSearch || _loadingRoute;
  String? get error => _error;
  String get globalSearchQuery => _globalSearchQuery;
  String get searchPrefix => _searchPrefix;
  double get nearbyRadiusKm => _nearbyRadiusKm;
  NearbyFilters get nearbyFilters => _nearbyFilters;
  MapDisplayState get mapState => _mapState;
  bool get isDemoMode => AppConfig.demoMode;
  bool get openMapTabRequest => _openMapTabRequest;
  LocationAccess get locationAccess => _locationAccess;
  bool get sortNearestFirst => _sortNearestFirst;

  /// Nearby list ranked by prominence (famous / large hospitals first).
  List<Hospital> get prominentNearby =>
      HospitalRepository.sortByProminence(_nearbyPool);

  List<Hospital> get mapHospitals {
    switch (_mapState.mode) {
      case MapViewMode.directions:
        if (_mapState.focusHospital != null) return [_mapState.focusHospital!];
        return const [];
      case MapViewMode.searchResult:
        if (_mapState.searchResults.isNotEmpty) return _mapState.searchResults;
        if (_mapState.focusHospital != null) return [_mapState.focusHospital!];
        return const [];
      case MapViewMode.nearby:
        return _nearby;
    }
  }

  Future<void> initialize() async {
    await _hospitalRepo.initialize();
    // Do not wait for GPS and the network here: the Nearby tab shows saved
    // results straight away and fills in live results when they arrive.
    unawaited(refreshNearby());
  }

  /// Used when the app returns from the background: skip the GPS fix and
  /// network search if the list was refreshed recently.
  Future<void> refreshNearbyIfStale() async {
    final last = _lastRefreshAt;
    // Without a live fix (e.g. the user just came back from the settings
    // screen after allowing location) always search again.
    if (last != null &&
        _nearbyPool.isNotEmpty &&
        _locationLive &&
        DateTime.now().difference(last) < _staleAfter) {
      return;
    }
    await refreshNearby();
  }

  /// "Allow location" / "Turn on" button: shows the permission dialog, or opens
  /// the right settings screen when Android will not show it any more.
  Future<void> requestLocationAndRefresh() async {
    final access = await PermissionUtils.requestLocationAccess();
    if (access == LocationAccess.deniedForever) {
      await LocationUtils.openAppSettings();
      return;
    }
    if (access == LocationAccess.serviceOff) {
      await LocationUtils.openLocationSettings();
      return;
    }
    await refreshNearby();
  }

  void setSortNearestFirst(bool value) {
    _sortNearestFirst = value;
    _applyNearbyFilters();
    notifyListeners();
  }

  Future<void> refreshNearby() async {
    if (_loadingNearby) return;
    _loadingNearby = true;
    _error = null;
    _lastRefreshAt = DateTime.now();
    notifyListeners();

    // 1. Show what is already saved on the phone, instantly.
    if (_nearbyPool.isEmpty) {
      try {
        final saved =
            await LocationUtils.getLastKnown() ?? await LocationStorage.load();
        if (saved != null) {
          final cached = await _hospitalRepo.loadCachedNearby(
            latitude: saved.latitude,
            longitude: saved.longitude,
          );
          if (cached.isNotEmpty && _nearbyPool.isEmpty) {
            _position ??= saved;
            _nearbyPool = cached;
            _applyNearbyFilters();
            notifyListeners();
          }
        }
      } catch (_) {
        // Saved data is only a shortcut; carry on with the live search.
      }
    }

    // 2. Fresh GPS fix (one attempt, with a time limit).
    Position? live;
    try {
      live = await LocationUtils.getCurrentPosition();
    } catch (_) {
      // e.g. another permission request is already on screen
      live = null;
    }
    if (live != null) {
      _position = live;
      _locationLive = true;
      _usingLastKnownLocation = false;
      _locationAccess = LocationAccess.granted;
    } else {
      try {
        _locationAccess = await PermissionUtils.locationAccess();
      } catch (_) {}
      // getCurrentPosition already tried (and failed), so use the phone's
      // last-known fix, then the app's saved one, instead of waiting for a
      // second GPS attempt.
      _position =
          await LocationUtils.getLastKnown() ?? await LocationStorage.load();
      _locationLive = false;
      _usingLastKnownLocation = _position != null;
    }

    if (_position == null) {
      _loadingNearby = false;
      _error = 'Turn on location to find nearby hospitals.';
      notifyListeners();
      return;
    }

    try {
      final result = await _hospitalRepo.fetchNearby(
        latitude: _position!.latitude,
        longitude: _position!.longitude,
      );
      _nearbyPool = result.hospitals;
      _nearbyRadiusKm = result.usedRadiusKm;
      _applyNearbyFilters();
      if (_mapState.mode == MapViewMode.nearby) {
        _mapState = _mapState.copyWith(clearFocus: true, clearRoute: true);
      }
    } catch (e) {
      _error = 'Could not load nearby facilities. ${e.toString()}';
    }

    _loadingNearby = false;
    notifyListeners();
  }

  void _applyNearbyFilters() {
    final filtered = _hospitalRepo.applyFilters(_nearbyPool, _nearbyFilters);
    if (_sortNearestFirst) {
      // Closest first. The pool itself stays in "top ranked" order.
      filtered.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
    }
    _nearby = filtered;
  }

  void updateSearchPrefix(String prefix) {
    _searchPrefix = prefix;
    _nameSuggestions = _hospitalRepo.nameSuggestions(_nearbyPool, prefix);
    notifyListeners();
  }

  void applyNameSearch(String query) {
    _searchPrefix = query;
    _nearbyFilters = _nearbyFilters.copyWith(nameQuery: query.trim());
    _nameSuggestions = [];
    _applyNearbyFilters();
    notifyListeners();
  }

  void clearNameSearch() {
    _searchPrefix = '';
    _nameSuggestions = [];
    _nearbyFilters = _nearbyFilters.copyWith(nameQuery: '');
    _applyNearbyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _nearbyFilters = _nearbyFilters.copyWith(
      category: category,
      clearCategory: category == null || category == 'all',
    );
    _applyNearbyFilters();
    notifyListeners();
  }

  void setSpecialityFilter(String? speciality) {
    _nearbyFilters = _nearbyFilters.copyWith(
      speciality: speciality,
      clearSpeciality: speciality == null || speciality.isEmpty,
    );
    _applyNearbyFilters();
    notifyListeners();
  }

  void setEmergencyFilter(bool value) {
    _nearbyFilters = _nearbyFilters.copyWith(emergencyOnly: value);
    _applyNearbyFilters();
    notifyListeners();
  }

  Future<void> searchEverywhere(String query) async {
    _globalSearchQuery = query.trim();
    if (_globalSearchQuery.isEmpty) {
      _globalSearchResults = [];
      showNearbyOnMap();
      notifyListeners();
      return;
    }

    _loadingGlobalSearch = true;
    _error = null;
    notifyListeners();

    _position ??= await LocationUtils.getEffectivePosition();
    if (_position == null) {
      _loadingGlobalSearch = false;
      _error = 'Turn on location for distance sorting.';
      notifyListeners();
      return;
    }
    final lat = _position!.latitude;
    final lng = _position!.longitude;

    try {
      _globalSearchResults = await _hospitalRepo.searchGlobally(
        query: _globalSearchQuery,
        userLatitude: lat,
        userLongitude: lng,
      );
    } catch (e) {
      _error = 'Search failed. ${e.toString()}';
      _globalSearchResults = [];
    }

    _loadingGlobalSearch = false;
    notifyListeners();
  }

  void focusSearchOnMap(Hospital hospital, {bool openMapTab = true}) {
    _mapState = MapDisplayState(
      mode: MapViewMode.searchResult,
      focusHospital: hospital,
      searchResults: _globalSearchResults,
    );
    if (openMapTab) _openMapTabRequest = true;
    notifyListeners();
  }

  Future<void> showDirectionsOnMap(Hospital hospital) async {
    _loadingRoute = true;
    _error = null;
    // Switch to the map straight away, focused on the destination, while the
    // route is fetched from OSRM.
    _mapState = MapDisplayState(
      mode: MapViewMode.directions,
      focusHospital: hospital,
    );
    _openMapTabRequest = true;
    notifyListeners();

    _position ??=
        await LocationUtils.getLastKnown() ?? await LocationUtils.getEffectivePosition();
    if (_position == null) {
      _loadingRoute = false;
      _error = 'Turn on location to get directions.';
      notifyListeners();
      return;
    }
    final lat = _position!.latitude;
    final lng = _position!.longitude;

    final route = await _routing.fetchDrivingRoute(
      fromLat: lat,
      fromLng: lng,
      toLat: hospital.latitude,
      toLng: hospital.longitude,
    );

    _loadingRoute = false;

    if (route == null) {
      _error = 'Could not load the route. Check your internet connection.';
      notifyListeners();
      return;
    }

    _mapState = MapDisplayState(
      mode: MapViewMode.directions,
      focusHospital: hospital,
      routePoints: route.points,
      routeDistanceKm: route.distanceKm,
      routeDurationMinutes: route.durationMinutes,
    );
    notifyListeners();
  }

  void showNearbyOnMap() {
    _mapState = const MapDisplayState(mode: MapViewMode.nearby);
    notifyListeners();
  }

  void clearMapTabRequest() {
    _openMapTabRequest = false;
  }

  Future<void> refresh() => refreshNearby();

  Future<void> loadFavorites(String userId) async {
    final ids = await _userRepo.getFavoriteIds(userId);
    _favoriteIds = ids.toSet();
    _favorites = await _hospitalRepo.getHospitalsByIds(ids);
    notifyListeners();
  }

  Set<String> _favoriteIds = {};

  Future<bool> toggleFavorite(String userId, String hospitalId) async {
    await _userRepo.toggleFavorite(userId, hospitalId);
    if (_favoriteIds.contains(hospitalId)) {
      _favoriteIds.remove(hospitalId);
      _favorites.removeWhere((h) => h.id == hospitalId);
    } else {
      _favoriteIds.add(hospitalId);
      final hospital = await _hospitalRepo.getHospital(hospitalId);
      if (hospital != null) _favorites.insert(0, hospital);
    }
    notifyListeners();
    return _favoriteIds.contains(hospitalId);
  }

  bool isFavorite(String hospitalId) => _favoriteIds.contains(hospitalId);

  Future<Hospital?> getHospitalDetails(String id) => _hospitalRepo.getHospital(id);

  Future<void> loadReviews(String hospitalId) async {
    _reviews = await _userRepo.getReviews(hospitalId);
    notifyListeners();
  }

  Future<void> submitReview({
    required String userId,
    required String hospitalId,
    required int rating,
    required String text,
  }) async {
    await _userRepo.addReview(
      userId: userId,
      hospitalId: hospitalId,
      rating: rating,
      reviewText: text,
    );
    await loadReviews(hospitalId);
  }

  List<Hospital> filterEmergencyOnly(List<Hospital> list) =>
      list.where((h) => h.emergencyAvailable).toList();

  Future<List<Hospital>> getAllCachedHospitals() => _hospitalRepo.getAllCached();

  Future<void> saveEnrichedHospital(Hospital hospital) async {
    await _hospitalRepo.cacheHospital(hospital);
    notifyListeners();
  }
}
