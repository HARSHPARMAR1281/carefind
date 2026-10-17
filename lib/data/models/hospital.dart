import 'package:flutter/material.dart';

class Hospital {
  Hospital({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    String? googlePlaceId,
    String? osmId,
    this.address = '',
    this.phone = '',
    this.rating = 0,
    this.totalReviews = 0,
    this.category = 'hospital',
    this.emergencyAvailable = false,
    this.verified = false,
    this.hasIcu = false,
    this.hasAmbulance = false,
    this.hasBloodBank = false,
    this.openingHours = '',
    this.specialities = const [],
    this.services = const [],
    this.cachedAt,
    this.distanceKm,
  })  : googlePlaceId = googlePlaceId ?? osmId ?? id,
        osmId = osmId ?? googlePlaceId ?? id;

  final String id;
  final String googlePlaceId;
  final String osmId;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final String phone;
  final double rating;
  final int totalReviews;
  final String category;
  final bool emergencyAvailable;
  final bool verified;
  final bool hasIcu;
  final bool hasAmbulance;
  final bool hasBloodBank;
  final String openingHours;
  final List<String> specialities;
  final List<String> services;
  final DateTime? cachedAt;
  final double? distanceKm;

  bool get hasPhone => phone.trim().isNotEmpty;

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'clinic':
        return 'Clinic';
      case 'pharmacy':
        return 'Pharmacy';
      case 'lab':
      case 'laboratory':
        return 'Lab';
      case 'dispensary':
        return 'Dispensary';
      default:
        return 'Hospital';
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'clinic':
        return Icons.medical_services_outlined;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'lab':
      case 'laboratory':
        return Icons.biotech;
      case 'dispensary':
        return Icons.medication;
      default:
        return Icons.local_hospital;
    }
  }

  Hospital copyWith({
    String? id,
    String? googlePlaceId,
    String? osmId,
    String? name,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    double? rating,
    int? totalReviews,
    String? category,
    bool? emergencyAvailable,
    bool? verified,
    bool? hasIcu,
    bool? hasAmbulance,
    bool? hasBloodBank,
    String? openingHours,
    List<String>? specialities,
    List<String>? services,
    DateTime? cachedAt,
    double? distanceKm,
  }) {
    return Hospital(
      id: id ?? this.id,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      osmId: osmId ?? this.osmId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      category: category ?? this.category,
      emergencyAvailable: emergencyAvailable ?? this.emergencyAvailable,
      verified: verified ?? this.verified,
      hasIcu: hasIcu ?? this.hasIcu,
      hasAmbulance: hasAmbulance ?? this.hasAmbulance,
      hasBloodBank: hasBloodBank ?? this.hasBloodBank,
      openingHours: openingHours ?? this.openingHours,
      specialities: specialities ?? this.specialities,
      services: services ?? this.services,
      cachedAt: cachedAt ?? this.cachedAt,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'google_place_id': googlePlaceId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'phone': phone,
        'rating': rating,
        'total_reviews': totalReviews,
        'category': category,
        'emergency_available': emergencyAvailable ? 1 : 0,
        'verified': verified ? 1 : 0,
        'has_icu': hasIcu ? 1 : 0,
        'has_ambulance': hasAmbulance ? 1 : 0,
        'has_blood_bank': hasBloodBank ? 1 : 0,
        'opening_hours': openingHours,
        'cached_at': cachedAt?.millisecondsSinceEpoch,
      };

  factory Hospital.fromMap(
    Map<String, dynamic> map, {
    List<String> specialities = const [],
    List<String> services = const [],
    double? distanceKm,
  }) {
    final id = map['id'] as String;
    final placeId = map['google_place_id'] as String? ?? id;
    return Hospital(
      id: id,
      googlePlaceId: placeId,
      osmId: map['osm_id'] as String? ?? placeId,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      totalReviews: map['total_reviews'] as int? ?? 0,
      category: map['category'] as String? ?? 'hospital',
      emergencyAvailable: (map['emergency_available'] as int? ?? 0) == 1,
      verified: (map['verified'] as int? ?? 0) == 1,
      hasIcu: (map['has_icu'] as int? ?? 0) == 1,
      hasAmbulance: (map['has_ambulance'] as int? ?? 0) == 1,
      hasBloodBank: (map['has_blood_bank'] as int? ?? 0) == 1,
      openingHours: map['opening_hours'] as String? ?? '',
      specialities: specialities,
      services: services,
      cachedAt: map['cached_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['cached_at'] as int)
          : null,
      distanceKm: distanceKm,
    );
  }
}
