import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'geo.dart';

/// Published Cambodia rate card. The fare is a pure function of these inputs.
const fareCard = 'leca-kh-1';

/// Straight-line kilometres times 1.3, and never under 500 metres.
int roadMeters(double straightKm) {
  final straight = (straightKm * 1000).round();
  final road = (straight * 1300 + 500) ~/ 1000;
  return road < 500 ? 500 : road;
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

class TripQuote {
  const TripQuote({
    required this.kind,
    required this.vehicle,
    required this.meters,
    required this.minutes,
    required this.cents,
    required this.proof,
  });

  final String kind;
  final String vehicle;
  final int meters;
  final int minutes;
  final int cents;
  final String proof;

  double get usd => cents / 100;

  double get kilometres => meters / 1000;

  bool get checksOut {
    final again = fareCents(
      kind: kind,
      vehicle: vehicle,
      meters: meters,
      minutes: minutes,
    );
    if (again != cents) return false;
    return proof ==
        fareProof(
          fareBody(
            kind: kind,
            vehicle: vehicle,
            meters: meters,
            minutes: minutes,
            cents: cents,
          ),
        );
  }
}

TripQuote priceTrip({
  required String kind,
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  String vehicle = '',
  int? traffic,
}) {
  final meters = roadMeters(kmBetween(fromLat, fromLng, toLat, toLng));
  final minutes = tripMinutes(meters, traffic);
  final cents = fareCents(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
  );
  final body = fareBody(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    cents: cents,
  );
  return TripQuote(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    cents: cents,
    proof: fareProof(body),
  );
}
