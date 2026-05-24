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
