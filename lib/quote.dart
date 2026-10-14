import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'geo.dart';
import 'rate_card.dart';

export 'rate_card.dart';

/// The card new quotes are priced on.
String get fareCard => RateCard.active.id;

int roadMeters(double straightKm) => RateCard.active.roadMeters(straightKm);

int tripMinutes(int meters, int? traffic) =>
    RateCard.active.tripMinutes(meters, traffic);

int rideScale(String vehicle) => RateCard.active.scale(vehicle);

/// Kinds: delivery, ride, rent (with a driver), rent-self (self-drive).
/// [hours] is the rental length; its time charge is a floor under the route.
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

class TripQuote {
  const TripQuote({
    required this.kind,
    required this.vehicle,
    required this.meters,
    required this.minutes,
    required this.cents,
    required this.proof,
    this.hours = 0,
    this.card = 'leca-kh-1',
    this.routed = false,
  });

  final String kind;
  final String vehicle;
  final int meters;
  final int minutes;
  final int hours;
  final int cents;
  final String proof;

  /// The card this quote was priced on. Proofs name it, so an old quote
  /// still checks after the card changes.
  final String card;

  /// Distance came from a routed road, not the straight-line estimate.
  final bool routed;

  double get usd => cents / 100;

  double get kilometres => meters / 1000;

  bool get checksOut {
    final rates = RateCard.known[card];
    if (rates == null) return false;
    final again = rates.fareCents(
      kind: kind,
      vehicle: vehicle,
      meters: meters,
      minutes: minutes,
      hours: hours,
    );
    if (again != cents) return false;
    return proof ==
        fareProof(
          fareBody(
            kind: kind,
            vehicle: vehicle,
            meters: meters,
            minutes: minutes,
            hours: hours,
            cents: cents,
            card: card,
          ),
        );
  }

  Map<String, Object?> toJson() => {
    'card': card,
    'kind': kind,
    'vehicle': vehicle,
    'meters': meters,
    'minutes': minutes,
    'hours': hours,
    'cents': cents,
    'proof': proof,
    'routed': routed,
  };

  /// A quote the server published, if it parses and checks out.
  /// Adopts [rates] so a new card is known before the proof is checked.
  static TripQuote? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final rates = RateCard.fromJson(raw['rates']);
    if (rates != null) RateCard.adopt(rates);
    final meters = raw['meters'];
    final minutes = raw['minutes'];
    final cents = raw['cents'];
    if (meters is! int || minutes is! int || cents is! int) return null;
    final hours = raw['hours'];
    final quote = TripQuote(
      kind: '${raw['kind']}',
      vehicle: '${raw['vehicle'] ?? ''}',
      meters: meters,
      minutes: minutes,
      hours: hours is int ? hours : 0,
      cents: cents,
      proof: '${raw['proof']}',
      card: '${raw['card'] ?? 'leca-kh-1'}',
      routed: raw['routed'] == true,
    );
    return quote.checksOut ? quote : null;
  }
}

/// Prices a trip on the active card. [routeMeters] is the road distance
/// from a routed call when one is known; otherwise the card's estimate.
TripQuote priceTrip({
  required String kind,
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
  String vehicle = '',
  int? traffic,
  int? routeMeters,
  int hours = 0,
}) {
  final card = RateCard.active;
  final routed = routeMeters != null && routeMeters >= card.minMeters;
  final meters = routed
      ? routeMeters
      : card.roadMeters(kmBetween(fromLat, fromLng, toLat, toLng));
  final minutes = card.tripMinutes(meters, traffic);
  final cents = card.fareCents(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    hours: hours,
  );
  final body = fareBody(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    hours: hours,
    cents: cents,
    card: card.id,
  );
  return TripQuote(
    kind: kind,
    vehicle: vehicle,
    meters: meters,
    minutes: minutes,
    hours: hours,
    cents: cents,
    proof: fareProof(body),
    card: card.id,
    routed: routed,
  );
}
