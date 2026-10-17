import 'hospital.dart';

/// Client-side filters applied to the nearby pool (no new API call).
class NearbyFilters {
  const NearbyFilters({
    this.nameQuery = '',
    this.category,
    this.speciality,
    this.emergencyOnly = false,
  });

  final String nameQuery;
  final String? category;
  final String? speciality;
  final bool emergencyOnly;

  static const commonSpecialities = [
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pediatrics',
    'Emergency',
    'Oncology',
    'Gynecology',
    'Dermatology',
    'General Medicine',
    'Trauma',
  ];

  static const categoryFilters = [
    ('all', 'All'),
    ('hospital', 'Hospitals'),
    ('clinic', 'Clinics'),
    ('pharmacy', 'Pharmacy'),
    ('laboratory', 'Labs'),
    ('dispensary', 'Dispensary'),
  ];

  NearbyFilters copyWith({
    String? nameQuery,
    String? category,
    String? speciality,
    bool? emergencyOnly,
    bool clearCategory = false,
    bool clearSpeciality = false,
  }) {
    return NearbyFilters(
      nameQuery: nameQuery ?? this.nameQuery,
      category: clearCategory ? null : (category ?? this.category),
      speciality: clearSpeciality ? null : (speciality ?? this.speciality),
      emergencyOnly: emergencyOnly ?? this.emergencyOnly,
    );
  }

  bool matches(Hospital h) {
    if (emergencyOnly && !h.emergencyAvailable) return false;

    if (category != null && category != 'all') {
      final cat = h.category.toLowerCase();
      final filter = category!.toLowerCase();
      if (filter == 'clinic' && !cat.contains('clinic') && cat != 'centre') {
        return false;
      }
      if (filter == 'pharmacy' &&
          !cat.contains('pharmacy') &&
          cat != 'chemist') {
        return false;
      }
      if (filter != 'clinic' &&
          filter != 'pharmacy' &&
          !cat.contains(filter)) {
        return false;
      }
    }

    if (speciality != null && speciality!.isNotEmpty) {
      final spec = speciality!.toLowerCase();
      final inTags = h.specialities.any((s) => s.toLowerCase().contains(spec));
      final inName = h.name.toLowerCase().contains(spec);
      if (!inTags && !inName) return false;
    }

    if (nameQuery.trim().isNotEmpty) {
      final q = nameQuery.trim().toLowerCase();
      final name = h.name.toLowerCase();
      if (!name.startsWith(q) &&
          !name.contains(q) &&
          !h.address.toLowerCase().contains(q)) {
        return false;
      }
    }

    return true;
  }

  bool get hasActiveFilters =>
      nameQuery.isNotEmpty ||
      (category != null && category != 'all') ||
      (speciality != null && speciality!.isNotEmpty) ||
      emergencyOnly;
}
