import '../../config/app_config.dart';
import '../../core/utils/distance_calculator.dart';
import '../database/hospital_database.dart';
import '../models/hospital.dart';
import '../models/map_mode.dart';
import '../models/nearby_filters.dart';
import '../services/osm_places_service.dart';

class HospitalRepository {
  HospitalRepository({
    HospitalDatabase? hospitalDb,
    OsmPlacesService? osmService,
  })  : _hospitalDb = hospitalDb ?? HospitalDatabase.instance,
        _osm = osmService ?? const OsmPlacesService();

  final HospitalDatabase _hospitalDb;
  final OsmPlacesService _osm;

  Future<void> initialize() async {
    await _hospitalDb.database;
    await _hospitalDb.seedDemoHospitals();
  }

  /// Fetches nearby facilities, expanding radius until 15–20 are found.
  Future<NearbyFetchResult> fetchNearby({
    required double latitude,
    required double longitude,
  }) async {
    List<Hospital> hospitals;
    double usedRadiusKm = AppConfig.defaultSearchRadiusKm;

    if (AppConfig.demoMode) {
      hospitals = [
        ..._osm.generateDemoNearby(latitude, longitude),
        ...(await _hospitalDb.getAll()),
      ];
    } else {
      try {
        final result = await _osm.fetchNearbyWithExpandingRadius(
          latitude: latitude,
          longitude: longitude,
        );
        hospitals = result.hospitals;
        usedRadiusKm = result.usedRadiusKm;
      } catch (_) {
        // Network search failed: fall back to saved facilities that are
        // actually near the user, never the whole table (which can hold
        // hospitals from other cities). If nothing is saved nearby, let the
        // error reach the UI so it can offer a retry.
        final saved = await loadCachedNearby(
          latitude: latitude,
          longitude: longitude,
          maxKm: 50,
        );
        if (saved.isEmpty) rethrow;
        hospitals = saved;
      }
    }

    for (final h in hospitals) {
      await cacheHospital(h);
    }

    var enriched = await _attachCachedEnrichment(hospitals);
    enriched = _withDistances(enriched, latitude, longitude);
    enriched = sortByProminence(enriched);

    return NearbyFetchResult(
      hospitals: _dedupeByOsmId(enriched),
      usedRadiusKm: usedRadiusKm,
    );
  }

  /// Facilities already saved on the phone near a point, used to fill the
  /// Nearby tab instantly while the live search runs.
  Future<List<Hospital>> loadCachedNearby({
    required double latitude,
    required double longitude,
    double maxKm = 25,
  }) async {
    final saved = await _hospitalDb.getNear(
      latitude: latitude,
      longitude: longitude,
      radiusKm: maxKm,
    );
    final near = _withDistances(saved, latitude, longitude)
        .where((h) => (h.distanceKm ?? 999) <= maxKm)
        .toList();
    return _dedupeByOsmId(sortByProminence(near))
        .take(AppConfig.targetNearbyHospitals)
        .toList();
  }

  /// Prioritises large / well-known hospitals; distance still matters but
  /// famous facilities can rank above smaller nearby clinics.
  static int prominenceScore(Hospital h) {
    var score = 0;
    if (h.category == 'hospital') score += 25;
    if (h.verified) score += 20;
    if (h.emergencyAvailable) score += 10;
    score += (h.rating * 3).round();
    score += (h.totalReviews / 50).round();

    final name = h.name.toLowerCase();
    const famousKeywords = [
      'apollo',
      'fortis',
      'manipal',
      'aiims',
      'max',
      'medanta',
      'narayana',
      'columbia',
      'aster',
      'kims',
      'global hospital',
      'sakra',
      'multispeciality',
      'multi speciality',
      'multi-speciality',
      'super speciality',
      'super-speciality',
      'care hospital',
      'ruby hall',
      'lilavati',
      'kokilaben',
      'jaypee',
      'blk',
      'pgimer',
    ];
    if (famousKeywords.any(name.contains)) score += 40;

    if (h.category == 'doctors' || h.category == 'doctor') score -= 30;
    if (h.category == 'pharmacy' ||
        h.category == 'chemist' ||
        h.category == 'medical_store') {
      score -= 25;
    }

    return score;
  }

  static double _rankScore(Hospital h) =>
      prominenceScore(h) - (h.distanceKm ?? 999) * 1.5;

  static List<Hospital> sortByProminence(List<Hospital> hospitals) {
    final sorted = [...hospitals];
    sorted.sort((a, b) => _rankScore(b).compareTo(_rankScore(a)));
    return sorted;
  }

  List<Hospital> applyFilters(List<Hospital> pool, NearbyFilters filters) {
    return pool.where(filters.matches).toList();
  }

  /// Name suggestions: prefix match first, Gthen contains (case insensitive).
  List<Hospital> nameSuggestions(List<Hospital> pool, String prefix, {int limit = 8}) {
    if (prefix.trim().isEmpty) return const [];

    final q = prefix.trim().toLowerCase();
    final startsWith = <Hospital>[];
    final contains = <Hospital>[];

    for (final h in pool) {
      final name = h.name.toLowerCase();
      if (name.startsWith(q)) {
        startsWith.add(h);
      } else if (name.contains(q)) {
        contains.add(h);
      }
    }

    startsWith.sort((a, b) => a.name.compareTo(b.name));
    contains.sort((a, b) => a.name.compareTo(b.name));

    return [...startsWith, ...contains].take(limit).toList();
  }

  Future<List<Hospital>> searchGlobally({
    required String query,
    required double userLatitude,
    required double userLongitude,
  }) async {
    if (query.trim().isEmpty) return [];

    List<Hospital> hospitals;

    if (AppConfig.demoMode) {
      final all = [
        ...(await _hospitalDb.getAll()),
        ..._osm.generateDemoNearby(userLatitude, userLongitude),
      ];
      final q = query.toLowerCase();
      hospitals = all
          .where((h) =>
              h.name.toLowerCase().contains(q) ||
              h.address.toLowerCase().contains(q))
          .toList();
    } else {
      hospitals = await _osm.searchGloballyIndia(query: query);
    }

    for (final h in hospitals) {
      await cacheHospital(h);
    }

    var enriched = await _attachCachedEnrichment(hospitals);
    enriched = _withDistances(enriched, userLatitude, userLongitude);
    return _dedupeByOsmId(sortByProminence(enriched));
  }

  List<Hospital> _dedupeByOsmId(List<Hospital> list) {
    final seen = <String>{};
    return list.where((h) => seen.add(h.osmId)).toList();
  }

  Future<List<Hospital>> _attachCachedEnrichment(List<Hospital> incoming) async {
    final result = <Hospital>[];
    for (final h in incoming) {
      final cached = await _hospitalDb.getByOsmId(h.osmId);
      if (cached != null && (cached.verified || cached.specialities.isNotEmpty)) {
        result.add(cached.copyWith(
          name: h.name,
          latitude: h.latitude,
          longitude: h.longitude,
          address: h.address.isNotEmpty ? h.address : cached.address,
          phone: h.phone.isNotEmpty ? h.phone : cached.phone,
          openingHours: h.openingHours.isNotEmpty ? h.openingHours : cached.openingHours,
          emergencyAvailable: h.emergencyAvailable || cached.emergencyAvailable,
          distanceKm: h.distanceKm,
        ));
      } else {
        result.add(h);
      }
    }
    return result;
  }

  List<Hospital> _withDistances(
    List<Hospital> hospitals,
    double lat,
    double lng,
  ) {
    return hospitals.map((h) {
      final km = DistanceCalculator.kmBetween(lat, lng, h.latitude, h.longitude);
      return h.copyWith(distanceKm: double.parse(km.toStringAsFixed(2)));
    }).toList();
  }

  Future<void> cacheHospital(Hospital hospital) async {
    await _hospitalDb.upsertHospital(hospital);
  }

  Future<Hospital?> getHospital(String id) async {
    var hospital = await _hospitalDb.getById(id);
    hospital ??= await _hospitalDb.getByOsmId(id);

    if (hospital == null && !AppConfig.demoMode) {
      final details = await _osm.fetchPlaceDetails(id);
      if (details != null) {
        await cacheHospital(details);
        hospital = details;
      }
    }
    return hospital;
  }

  Future<List<Hospital>> getHospitalsByIds(List<String> ids) async {
    return _hospitalDb.getByIds(ids);
  }

  Future<List<Hospital>> getAllCached() async {
    return _hospitalDb.getAll();
  }
}

