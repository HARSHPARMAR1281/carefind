import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../../core/utils/distance_calculator.dart';
import '../models/hospital.dart';

/// Fetches medical facilities from OpenStreetMap via Overpass API and Nominatim.
class OsmPlacesService {
  const OsmPlacesService();
  static const _uuid = Uuid();

  static const _amenityTypes = 'hospital|clinic|doctors|pharmacy|dentist';
  static const _healthcareTypes =
      'hospital|clinic|laboratory|pharmacy|dispensary|centre|doctor|blood_donation';
  static const _nominatimMedicalClasses = {
    'amenity',
    'healthcare',
    'shop',
    'office',
  };

  /// Public OSM servers can be slow; fail fast so the app can fall back to
  /// saved data instead of waiting indefinitely.
  static const _requestTimeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'User-Agent': AppConfig.osmUserAgent,
        'Accept': 'application/json',
      };

  Future<List<Hospital>> fetchNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusKm = AppConfig.defaultSearchRadiusKm,
  }) async {
    if (AppConfig.demoMode) return [];

    final radiusMeters = (radiusKm * 1000).round();
    final query = '''
[out:json][timeout:30];
(
  nwr["amenity"~"(^|;)($_amenityTypes)(;|\$)"](around:$radiusMeters,$latitude,$longitude);
  nwr["healthcare"~"(^|;)($_healthcareTypes)(;|\$)"](around:$radiusMeters,$latitude,$longitude);
  nwr["shop"="medical_supply"](around:$radiusMeters,$latitude,$longitude);
  nwr["shop"="chemist"](around:$radiusMeters,$latitude,$longitude);
  nwr["amenity"="emergency_department"](around:$radiusMeters,$latitude,$longitude);
);
out center tags;
''';

    final url = Uri.parse(AppConfig.overpassApiUrl);
    final response = await http
        .post(
          url,
          headers: _headers,
          body: {'data': query},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Overpass API request failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    return elements
        .map((e) => _fromOverpassElement(e as Map<String, dynamic>))
        .whereType<Hospital>()
        .toList();
  }

  /// Category-targeted Overpass query (pharmacy, clinic, hospital, etc.).
  Future<List<Hospital>> fetchByCategoryAtRadius({
    required String category,
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    if (AppConfig.demoMode) {
      return generateDemoNearby(latitude, longitude)
          .where((h) => _matchesCategoryFilter(h.category, category))
          .toList();
    }

    final radiusMeters = (radiusKm * 1000).round();
    final query = _categoryOverpassQuery(
      category: category,
      radiusMeters: radiusMeters,
      latitude: latitude,
      longitude: longitude,
    );

    final url = Uri.parse(AppConfig.overpassApiUrl);
    final response = await http
        .post(
          url,
          headers: _headers,
          body: {'data': query},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Overpass API request failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    return elements
        .map((e) => _fromOverpassElement(e as Map<String, dynamic>))
        .whereType<Hospital>()
        .where((h) => _matchesCategoryFilter(h.category, category))
        .toList();
  }

  /// Expands radius until enough [category] facilities are found (up to 150 km).
  Future<({List<Hospital> hospitals, double usedRadiusKm})>
      fetchCategoryWithExpandingRadius({
    required String category,
    required double latitude,
    required double longitude,
  }) async {
    if (AppConfig.demoMode) {
      final demos = generateDemoNearby(latitude, longitude)
          .where((h) => _matchesCategoryFilter(h.category, category))
          .toList();
      return (hospitals: demos, usedRadiusKm: AppConfig.defaultSearchRadiusKm);
    }

    final accumulated = <String, Hospital>{};
    var usedRadiusKm = AppConfig.defaultSearchRadiusKm;

    for (final radiusKm in AppConfig.searchRadiusStepsKm) {
      usedRadiusKm = radiusKm;
      final batch = await fetchByCategoryAtRadius(
        category: category,
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      for (final h in batch) {
        accumulated[h.osmId] = h;
      }

      if (accumulated.length >= AppConfig.minCategoryResults ||
          radiusKm >= AppConfig.maxSearchRadiusKm) {
        break;
      }
    }

    final list = accumulated.values.toList();
    list.sort((a, b) {
      final da = DistanceCalculator.kmBetween(
        latitude,
        longitude,
        a.latitude,
        a.longitude,
      );
      final db = DistanceCalculator.kmBetween(
        latitude,
        longitude,
        b.latitude,
        b.longitude,
      );
      return da.compareTo(db);
    });

    return (hospitals: list, usedRadiusKm: usedRadiusKm);
  }

  String _categoryOverpassQuery({
    required String category,
    required int radiusMeters,
    required double latitude,
    required double longitude,
  }) {
    final around = 'around:$radiusMeters,$latitude,$longitude';
    final clauses = switch (category) {
      'pharmacy' => '''
  nwr["amenity"="pharmacy"]($around);
  nwr["shop"="chemist"]($around);
  nwr["healthcare"="pharmacy"]($around);
''',
      'clinic' => '''
  nwr["amenity"~"clinic|doctors"]($around);
  nwr["healthcare"~"clinic|doctor|centre|center"]($around);
''',
      'hospital' => '''
  nwr["amenity"="hospital"]($around);
  nwr["healthcare"="hospital"]($around);
''',
      'laboratory' => '''
  nwr["healthcare"="laboratory"]($around);
  nwr["amenity"="laboratory"]($around);
''',
      'dispensary' => '''
  nwr["healthcare"="dispensary"]($around);
  nwr["amenity"="clinic"]["healthcare"="dispensary"]($around);
''',
      _ => '''
  nwr["amenity"~"(^|;)($_amenityTypes)(;|\$)"]($around);
  nwr["healthcare"~"(^|;)($_healthcareTypes)(;|\$)"]($around);
''',
    };

    return '''
[out:json][timeout:45];
(
$clauses);
out center tags;
''';
  }

  bool _matchesCategoryFilter(String hospitalCategory, String filter) {
    final cat = hospitalCategory.toLowerCase();
    final f = filter.toLowerCase();
    if (f == 'clinic') {
      return cat.contains('clinic') || cat == 'centre' || cat == 'center' ||
          cat == 'doctors' || cat == 'doctor';
    }
    if (f == 'pharmacy') {
      return cat.contains('pharmacy') || cat == 'chemist';
    }
    if (f == 'laboratory') return cat.contains('laborator');
    if (f == 'dispensary') return cat.contains('dispensary');
    if (f == 'hospital') return cat == 'hospital';
    return cat.contains(f);
  }

  /// India-wide search via Nominatim (no location bias).
  Future<List<Hospital>> searchGloballyIndia({
    required String query,
    int limit = 20,
  }) async {
    if (AppConfig.demoMode || query.trim().isEmpty) return [];

    final params = <String, String>{
      'q': query.trim(),
      'format': 'json',
      'limit': limit.toString(),
      'addressdetails': '1',
      'countrycodes': 'in',
    };

    final url = Uri.parse('${AppConfig.nominatimApiUrl}/search')
        .replace(queryParameters: params);
    final response = await http.get(url, headers: _headers).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Nominatim search failed (${response.statusCode})');
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    return results
        .map((r) => _fromNominatimResult(
              r as Map<String, dynamic>,
              allowBroadMedicalMatch: true,
            ))
        .whereType<Hospital>()
        .toList();
  }

  /// Local-biased search (legacy helper for nearby area).
  Future<List<Hospital>> searchHospitals({
    required String query,
    double? latitude,
    double? longitude,
    int limit = 15,
  }) async {
    if (AppConfig.demoMode || query.trim().isEmpty) return [];

    final params = <String, String>{
      'q': '$query hospital clinic pharmacy dispensary medical',
      'format': 'json',
      'limit': (limit * 2).toString(),
      'addressdetails': '1',
    };
    if (latitude != null && longitude != null) {
      params['lat'] = latitude.toString();
      params['lon'] = longitude.toString();
    }

    final url = Uri.parse('${AppConfig.nominatimApiUrl}/search')
        .replace(queryParameters: params);
    final response = await http.get(url, headers: _headers).timeout(_requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Nominatim search failed (${response.statusCode})');
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    return results
        .map((r) => _fromNominatimResult(r as Map<String, dynamic>))
        .whereType<Hospital>()
        .take(limit)
        .toList();
  }

  /// Expands radius until [AppConfig.minNearbyHospitals] found or max radius reached.
  /// Accumulates results across steps and returns the closest facilities.
  Future<({List<Hospital> hospitals, double usedRadiusKm})>
      fetchNearbyWithExpandingRadius({
    required double latitude,
    required double longitude,
  }) async {
    if (AppConfig.demoMode) {
      return (hospitals: <Hospital>[], usedRadiusKm: AppConfig.defaultSearchRadiusKm);
    }

    final accumulated = <String, Hospital>{};
    var usedRadiusKm = AppConfig.defaultSearchRadiusKm;

    for (final radiusKm in AppConfig.searchRadiusStepsKm) {
      usedRadiusKm = radiusKm;
      final batch = await fetchNearbyHospitals(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
      );

      for (final h in batch) {
        accumulated[h.osmId] = h;
      }

      if (accumulated.length >= AppConfig.minNearbyHospitals ||
          radiusKm >= AppConfig.maxSearchRadiusKm) {
        break;
      }
    }

    final list = accumulated.values.toList();
    list.sort((a, b) {
      final da = DistanceCalculator.kmBetween(latitude, longitude, a.latitude, a.longitude);
      final db = DistanceCalculator.kmBetween(latitude, longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    final capped = list.take(AppConfig.targetNearbyHospitals).toList();
    return (hospitals: capped, usedRadiusKm: usedRadiusKm);
  }

  Future<Hospital?> fetchPlaceDetails(String osmId) async {
    if (AppConfig.demoMode) return null;

    final parsed = _parseOsmId(osmId);
    if (parsed == null) return null;

    final (type, id) = parsed;
    final query = '''
[out:json][timeout:15];
$type($id);
out center tags;
''';

    final url = Uri.parse(AppConfig.overpassApiUrl);
    final response = await http
        .post(
          url,
          headers: _headers,
          body: {'data': query},
        )
        .timeout(_requestTimeout);

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];
    if (elements.isEmpty) return null;

    return _fromOverpassElement(elements.first as Map<String, dynamic>);
  }

  Hospital? _fromOverpassElement(Map<String, dynamic> element) {
    final type = element['type'] as String?;
    final id = element['id'];
    if (type == null || id == null) return null;

    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    final name = tags['name'] as String?;
    if (name == null || name.isEmpty) return null;

    final lat = _elementLat(element);
    final lng = _elementLon(element);
    if (lat == null || lng == null) return null;

    final osmId = '$type/$id';

    return Hospital(
      id: osmId,
      osmId: osmId,
      name: name,
      latitude: lat,
      longitude: lng,
      address: _addressFromTags(tags),
      phone: _phoneFromTags(tags),
      emergencyAvailable: _isEmergency(tags),
      openingHours: tags['opening_hours'] as String? ?? '',
      category: _categoryFromTags(tags),
      specialities: _specialitiesFromTags(tags),
      cachedAt: DateTime.now(),
    );
  }

  List<String> _specialitiesFromTags(Map<String, dynamic> tags) {
    final raw = tags['healthcare:speciality'] as String? ??
        tags['healthcare_speciality'] as String?;
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1))
        .toList();
  }

  static const _medicalNominatimTypes = {
    'hospital',
    'clinic',
    'pharmacy',
    'chemist',
    'doctors',
    'dentist',
    'laboratory',
    'healthcare',
  };

  static const _medicalKeywords = [
    'hospital',
    'clinic',
    'medical',
    'pharmacy',
    'dispensary',
    'diagnostic',
    'laboratory',
    'apollo',
    'fortis',
    'aiims',
    'max hospital',
    'narayana',
    'manipal',
    'blood bank',
    'health centre',
    'health center',
  ];

  bool _containsMedicalKeyword(String text) {
    final lower = text.toLowerCase();
    return _medicalKeywords.any((k) => lower.contains(k));
  }

  Hospital? _fromNominatimResult(
    Map<String, dynamic> result, {
    bool allowBroadMedicalMatch = false,
  }) {
    final osmClass = result['class'] as String?;
    final type = result['type'] as String? ?? '';
    final displayNameRaw = result['display_name'] as String? ?? '';
    final nameRaw = result['name'] as String? ?? '';
    final combined = '$nameRaw $displayNameRaw'.toLowerCase();

    final isMedicalClass =
        osmClass != null && _nominatimMedicalClasses.contains(osmClass);
    final isMedicalType = _medicalNominatimTypes.contains(type);
    final isMedicalKeyword = _containsMedicalKeyword(combined);

    if (allowBroadMedicalMatch) {
      if (!isMedicalClass && !isMedicalType && !isMedicalKeyword) return null;
    } else if (!isMedicalClass && !isMedicalType) {
      return null;
    }

    final osmType = result['osm_type'] as String?;
    final osmIdNum = result['osm_id'];
    if (osmType == null || osmIdNum == null) return null;

    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;

    final osmId = '$osmType/$osmIdNum';
    final resolvedName = nameRaw.trim().isNotEmpty
        ? nameRaw.trim()
        : displayNameRaw.split(',').first.trim();

    if (resolvedName.isEmpty) return null;

    return Hospital(
      id: osmId,
      osmId: osmId,
      name: resolvedName,
      latitude: lat,
      longitude: lng,
      address: displayNameRaw,
      category: _categoryFromNominatim(result),
      cachedAt: DateTime.now(),
    );
  }

  String _categoryFromNominatim(Map<String, dynamic> result) {
    final type = result['type'] as String? ?? '';
    final typeMap = {
      'hospital': 'hospital',
      'clinic': 'clinic',
      'pharmacy': 'pharmacy',
      'chemist': 'pharmacy',
      'doctors': 'doctors',
      'dentist': 'dentist',
      'laboratory': 'laboratory',
    };
    return typeMap[type] ?? type;
  }

  String _categoryFromTags(Map<String, dynamic> tags) {
    final healthcare = tags['healthcare'] as String?;
    if (healthcare != null && healthcare.isNotEmpty) {
      if (healthcare.contains('laboratory')) return 'laboratory';
      return healthcare.split(';').first.trim();
    }

    final amenity = tags['amenity'] as String?;
    if (amenity != null && amenity.isNotEmpty) return amenity;

    final shop = tags['shop'] as String?;
    if (shop == 'medical_supply') return 'medical_store';
    if (shop == 'chemist') return 'pharmacy';

    return 'medical';
  }

  double? _elementLat(Map<String, dynamic> element) {
    if (element['lat'] != null) return (element['lat'] as num).toDouble();
    final center = element['center'] as Map<String, dynamic>?;
    if (center?['lat'] != null) return (center!['lat'] as num).toDouble();
    return null;
  }

  double? _elementLon(Map<String, dynamic> element) {
    if (element['lon'] != null) return (element['lon'] as num).toDouble();
    final center = element['center'] as Map<String, dynamic>?;
    if (center?['lon'] != null) return (center!['lon'] as num).toDouble();
    return null;
  }

  String _addressFromTags(Map<String, dynamic> tags) {
    final full = tags['addr:full'] as String?;
    if (full != null && full.isNotEmpty) return full;

    final parts = <String>[
      tags['addr:housenumber'] as String? ?? '',
      tags['addr:street'] as String? ?? '',
      tags['addr:suburb'] as String? ?? '',
      tags['addr:city'] as String? ?? tags['addr:town'] as String? ?? '',
      tags['addr:state'] as String? ?? '',
      tags['addr:postcode'] as String? ?? '',
    ].where((p) => p.isNotEmpty).toList();

    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  String _phoneFromTags(Map<String, dynamic> tags) {
    const phoneKeys = [
      'phone',
      'contact:phone',
      'contact:mobile',
      'phone:mobile',
      'contact:telephone',
      'mobile',
      'telephone',
    ];

    for (final key in phoneKeys) {
      final value = tags[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  bool _isEmergency(Map<String, dynamic> tags) {
    final emergency = tags['emergency']?.toString().toLowerCase();
    if (emergency == 'yes') return true;
    final speciality = tags['healthcare:speciality']?.toString().toLowerCase() ?? '';
    if (speciality.contains('emergency')) return true;
    return tags['amenity'] == 'emergency_department';
  }

  (String, int)? _parseOsmId(String osmId) {
    final parts = osmId.split('/');
    if (parts.length != 2) return null;
    final id = int.tryParse(parts[1]);
    if (id == null) return null;
    return (parts[0], id);
  }

  List<Hospital> generateDemoNearby(double lat, double lng) {
    return [
      Hospital(
        id: _uuid.v4(),
        osmId: 'demo_nearby_1',
        name: 'Metro Emergency Hospital',
        latitude: lat + 0.008,
        longitude: lng + 0.006,
        address: 'Near your location',
        phone: '+911800123456',
        category: 'hospital',
        emergencyAvailable: true,
        verified: true,
        hasIcu: true,
        hasAmbulance: true,
        specialities: const ['Trauma', 'Emergency Medicine'],
        services: const ['24/7 Emergency', 'ICU', 'Ambulance'],
        cachedAt: DateTime.now(),
      ),
      Hospital(
        id: _uuid.v4(),
        osmId: 'demo_nearby_2',
        name: 'Green Valley Medical Center',
        latitude: lat - 0.005,
        longitude: lng + 0.01,
        address: 'Near your location',
        phone: '+911800987654',
        category: 'clinic',
        verified: true,
        hasBloodBank: true,
        specialities: const ['General Medicine', 'Pediatrics'],
        services: const ['OPD', 'Diagnostics', 'Pharmacy'],
        cachedAt: DateTime.now(),
      ),
      Hospital(
        id: _uuid.v4(),
        osmId: 'demo_nearby_3',
        name: 'City Care Pharmacy & Lab',
        latitude: lat + 0.003,
        longitude: lng - 0.007,
        address: 'Near your location',
        phone: '+911123456789',
        category: 'pharmacy',
        services: const ['Pharmacy', 'Blood Tests', 'X-Ray'],
        cachedAt: DateTime.now(),
      ),
      Hospital(
        id: _uuid.v4(),
        osmId: 'demo_nearby_4',
        name: 'Manipal Hospital',
        latitude: lat + 0.012,
        longitude: lng + 0.004,
        address: 'Near your location',
        phone: '+911800555123',
        category: 'hospital',
        specialities: const ['Cardiology', 'Neurology', 'Orthopedics'],
        services: const ['Emergency', 'ICU', 'Diagnostics'],
        verified: true,
        cachedAt: DateTime.now(),
      ),
    ];
  }
}
