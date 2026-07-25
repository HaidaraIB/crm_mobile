/// Default map center (Baghdad area — same as web CRM).
const defaultMapCenterLat = 33.3152;
const defaultMapCenterLng = 44.3661;

double? parseLeadCoordinate(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  return n;
}

/// API body for optional lead map location (both set or both cleared).
Map<String, dynamic> buildLeadLocationApiBody({
  double? latitude,
  double? longitude,
}) {
  if (latitude == null || longitude == null) {
    return {
      'location_latitude': null,
      'location_longitude': null,
    };
  }
  return {
    'location_latitude': double.parse(latitude.toStringAsFixed(6)),
    'location_longitude': double.parse(longitude.toStringAsFixed(6)),
  };
}

/// Map API ClientEvent.notes keys to i18n keys for location updates.
String clientLocationEventTranslationKey(String? notes) {
  switch (notes) {
    case 'lead_location_cleared':
      return 'leadLocationCleared';
    case 'lead_location_set':
      return 'leadLocationSet';
    default:
      return 'leadLocationUpdated';
  }
}

String? formatClientLocationPair(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

String? clientLocationMapsUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parts = value.split(',');
  if (parts.length != 2) return null;
  final lat = double.tryParse(parts[0].trim());
  final lng = double.tryParse(parts[1].trim());
  if (lat == null || lng == null) return null;
  return 'https://www.google.com/maps?q=$lat,$lng';
}
