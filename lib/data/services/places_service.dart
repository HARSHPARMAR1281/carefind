import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/app_config.dart';
import '../models/hospital.dart';

/// Fetches hospitals from Google Places API (discovery layer).
class PlacesService {
  const PlacesService();
  static const _uuid = Uuid();

  Future<List<Hospital>> fetchNearbyHospitals({
    required double latitude,
    required double longitude,
    double radiusKm = AppConfig.defaultSearchRadiusKm,
  }) async {
    if (AppConfig.demoMode) return [];

    final radiusMeters = (radiusKm * 1000).round();
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
      '?location=$latitude,$longitude'
      '&radius=$radiusMeters'
      '&type=hospital'
      '&key=${AppConfig.googlePlacesApiKey}',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('Places API request failed (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception('Places API: $status');
    }

    final results = data['results'] as List<dynamic>? ?? [];
    return results.map((place) => _fromPlaceResult(place as Map<String, dynamic>)).toList();
  }

  Hospital _fromPlaceResult(Map<String, dynamic> place) {
    final placeId = place['place_id'] as String;
    final geometry = place['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final lat = (location['lat'] as num).toDouble();
    final lng = (location['lng'] as num).toDouble();

    return Hospital(
      id: placeId,
      googlePlaceId: placeId,
      name: place['name'] as String? ?? 'Hospital',
      latitude: lat,
      longitude: lng,
      address: place['vicinity'] as String? ?? '',
      rating: (place['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: place['user_ratings_total'] as int? ?? 0,
      emergencyAvailable: (place['opening_hours']?['open_now'] as bool?) ?? false,
      cachedAt: DateTime.now(),
    );
  }

  Future<Hospital?> fetchPlaceDetails(String placeId) async {
    if (AppConfig.demoMode) return null;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId'
      '&fields=name,formatted_address,formatted_phone_number,rating,user_ratings_total,geometry,opening_hours,types'
      '&key=${AppConfig.googlePlacesApiKey}',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;

    final result = data['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return Hospital(
      id: placeId,
      googlePlaceId: placeId,
      name: result['name'] as String? ?? 'Hospital',
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      address: result['formatted_address'] as String? ?? '',
      phone: result['formatted_phone_number'] as String? ?? '',
      rating: (result['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: result['user_ratings_total'] as int? ?? 0,
      openingHours: result['opening_hours']?['weekday_text']?.join(', ') ?? '',
      cachedAt: DateTime.now(),
    );
  }

  /// Demo hospitals offset slightly from user location.
  List<Hospital> generateDemoNearby(double lat, double lng) {
    return [
      Hospital(
        id: _uuid.v4(),
        googlePlaceId: 'demo_nearby_1',
        name: 'Metro Emergency Hospital',
        latitude: lat + 0.008,
        longitude: lng + 0.006,
        address: 'Near your location',
        phone: '+91-1800-123-456',
        rating: 4.4,
        totalReviews: 890,
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
        googlePlaceId: 'demo_nearby_2',
        name: 'Green Valley Medical Center',
        latitude: lat - 0.005,
        longitude: lng + 0.01,
        address: 'Near your location',
        phone: '+91-1800-987-654',
        rating: 4.1,
        totalReviews: 412,
        emergencyAvailable: false,
        verified: true,
        hasBloodBank: true,
        specialities: const ['General Medicine', 'Pediatrics'],
        services: const ['OPD', 'Diagnostics', 'Pharmacy'],
        cachedAt: DateTime.now(),
      ),
    ];
  }
}
