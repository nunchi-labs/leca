import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

const fareCard = 'leca-kh-1';

int roadMeters(double straightKm) {
  final straight = (straightKm * 1000).round();
  final road = (straight * 1300 + 500) ~/ 1000;
  return road < 500 ? 500 : road;
}

double _km(double lat1, double lng1, double lat2, double lng2) {
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

int tripMinutes(int meters, int? traffic) {
  if (traffic != null) {
    if (traffic < 1) return 1;
    if (traffic > 1440) return 1440;
    return traffic;
  }
  final estimate = (meters * 3 + 999) ~/ 1000;
  return estimate < 1 ? 1 : estimate;
}

int rideScale(String vehicle) {
  switch (vehicle) {
    case 'bicycle':
      return 70;
    case 'motorcycle':
      return 100;
    case 'tuktuk':
      return 130;
    case 'remorque':
      return 140;
    case 'car':
      return 180;
    case 'van6':
      return 220;
    default:
      return 130;
  }
}

/// Kinds: delivery, ride, rent (with a driver), rent-self (self-drive).
int fareCents({
  required String kind,
  required String vehicle,
  required int meters,
  required int minutes,
}) {
  final wheels = kind == 'ride' || kind == 'rent' || kind == 'rent-self';
  final base = kind == 'delivery'
      ? 40
      : kind == 'ride'
      ? 50
      : 100;
  final perKm = wheels ? 22 : 18;
  final perMin = kind == 'rent-self'
      ? 0
      : wheels
      ? 3
      : 2;
  final scale = wheels ? rideScale(vehicle) : 100;
  final raw = base + (meters * perKm + 500) ~/ 1000 + minutes * perMin;
  final scaled = (raw * scale + 50) ~/ 100;
  return scaled < 50 ? 50 : scaled;
}

String fareBody({
  required String kind,
  required String vehicle,
  required int meters,
  required int minutes,
  required int cents,
}) {
  return 'leca-fare/1\n'
      'card=$fareCard\n'
      'kind=$kind\n'
      'vehicle=$vehicle\n'
      'meters=$meters\n'
      'minutes=$minutes\n'
      'fare=$cents\n';
}

String fareProof(String body) => sha256.convert(utf8.encode(body)).toString();

Map<String, Object?> quoteTrip(Map<String, Object?> body) {
  const kinds = {'ride', 'rent', 'rent-self', 'delivery'};
  final asked = '${body['kind'] ?? ''}';
  final kind = kinds.contains(asked) ? asked : 'delivery';
  final vehicle = kind == 'delivery' ? '' : '${body['vehicle'] ?? ''}';
  final fromLat = _coord(body['fromLat']);
  final fromLng = _coord(body['fromLng']);
  final toLat = _coord(body['toLat']);
  final toLng = _coord(body['toLng']);
  if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
    throw FormatException('quote_invalid');
  }
  final meters = roadMeters(_km(fromLat, fromLng, toLat, toLng));
  final traffic = body['minutes'];
  final minutes = tripMinutes(meters, traffic is int ? traffic : null);
  final cents = fareCents(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
  );
  final proof = fareProof(
    fareBody(
      kind: kind,
      vehicle: vehicle,
      meters: meters,
      minutes: minutes,
      cents: cents,
    ),
  );
  return {
    'card': fareCard,
    'kind': kind,
    'vehicle': vehicle,
    'meters': meters,
    'minutes': minutes,
    'cents': cents,
    'proof': proof,
  };
}

double? _coord(Object? raw) {
  if (raw is! num) return null;
  final value = raw.toDouble();
  if (value.isNaN || value.abs() > 180) return null;
  return value;
}
