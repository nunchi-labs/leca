import 'dart:math' as math;

import 'location.dart';

/// Kilometres between two WGS84 points.
double kmBetween(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// A point [kmNorth] kilometres north of [origin]. Used for nearby jobs.
TripFix northOf(TripFix origin, double kmNorth) {
  return TripFix(
    latitude: origin.latitude + kmNorth / 111.0,
    longitude: origin.longitude,
  );
}
