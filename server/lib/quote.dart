import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'rate_card.dart';

export 'rate_card.dart';

String get fareCard => RateCard.active.id;

int roadMeters(double straightKm) => RateCard.active.roadMeters(straightKm);

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

int tripMinutes(int meters, int? traffic) =>
    RateCard.active.tripMinutes(meters, traffic);

int rideScale(String vehicle) => RateCard.active.scale(vehicle);

/// Kinds: delivery, ride, rent (with a driver), rent-self (self-drive).
int fareCents({
  required String kind,
  required String vehicle,
  required int meters,
  required int minutes,
  int hours = 0,
  RateCard? card,
}) => (card ?? RateCard.active).fareCents(
  kind: kind,
  vehicle: vehicle,
  meters: meters,
  minutes: minutes,
  hours: hours,
);

String fareBody({
  required String kind,
  required String vehicle,
  required int meters,
  required int minutes,
  required int cents,
  int hours = 0,
  String? card,
}) {
  return 'leca-fare/2\n'
      'card=${card ?? fareCard}\n'
      'kind=$kind\n'
      'vehicle=$vehicle\n'
      'meters=$meters\n'
      'minutes=$minutes\n'
      'hours=$hours\n'
      'fare=$cents\n';
}

String fareProof(String body) => sha256.convert(utf8.encode(body)).toString();

/// Prices a trip. Accepts routed `meters` and traffic `minutes` when the
/// caller has them; the proof covers whichever distance was used.
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
  final card = RateCard.active;
  final routeMeters = body['meters'];
  final routed =
      routeMeters is int &&
      routeMeters >= card.minMeters &&
      routeMeters <= 2000000;
  final meters = routed
      ? routeMeters
      : card.roadMeters(_km(fromLat, fromLng, toLat, toLng));
  final traffic = body['minutes'];
  final minutes = card.tripMinutes(meters, traffic is int ? traffic : null);
  final rawHours = body['hours'];
  final hours = rawHours is int && rawHours > 0 && rawHours <= 24 * 90
      ? rawHours
      : 0;
  final cents = card.fareCents(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    hours: hours,
  );
  final proof = fareProof(
    fareBody(
      kind: kind,
      vehicle: vehicle,
      meters: meters,
      minutes: minutes,
      hours: hours,
      cents: cents,
      card: card.id,
    ),
  );
  return {
    'card': card.id,
    'kind': kind,
    'vehicle': vehicle,
    'meters': meters,
    'minutes': minutes,
    'hours': hours,
    'cents': cents,
    'proof': proof,
    'routed': routed,
    'rates': card.toJson(),
  };
}

double? _coord(Object? raw) {
  if (raw is! num) return null;
  final value = raw.toDouble();
  if (value.isNaN || value.abs() > 180) return null;
  return value;
}
