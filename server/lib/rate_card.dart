// Shared by the app and the server. Keep server/lib/rate_card.dart identical.

/// One kind of trip on a rate card: delivery, ride, rent, rent-self.
class RateKind {
  const RateKind({
    required this.base,
    required this.perKm,
    required this.perMin,
    this.perHour = 0,
    this.scaled = true,
  });

  /// Cents before the vehicle scale is applied.
  final int base;
  final int perKm;
  final int perMin;

  /// Cents per billable hour for rentals. The route fare is the floor.
  final int perHour;

  /// Whether the vehicle scale applies to this kind.
  final bool scaled;

  Map<String, Object?> toJson() => {
    'base': base,
    'perKm': perKm,
    'perMin': perMin,
    'perHour': perHour,
    'scaled': scaled,
  };

  static RateKind? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final base = raw['base'];
    final perKm = raw['perKm'];
    final perMin = raw['perMin'];
    if (base is! int || perKm is! int || perMin is! int) return null;
    final perHour = raw['perHour'];
    return RateKind(
      base: base,
      perKm: perKm,
      perMin: perMin,
      perHour: perHour is int ? perHour : 0,
      scaled: raw['scaled'] != false,
    );
  }
}

/// A published fare schedule. The fare is a pure function of a card and
/// the trip inputs, so a proof that names its card can always be rechecked.
class RateCard {
  const RateCard({
    required this.id,
    required this.kinds,
    required this.scales,
    this.defaultScale = 130,
    this.minCents = 50,
    this.roadFactor = 1300,
    this.minMeters = 500,
    this.fallbackMinPerKm = 3,
    this.dayHours = 8,
  });

  final String id;
  final Map<String, RateKind> kinds;

  /// Percent multipliers by vehicle id.
  final Map<String, int> scales;
  final int defaultScale;
  final int minCents;

  /// Straight-line to road distance, in thousandths (1300 = ×1.3).
  final int roadFactor;
  final int minMeters;

  /// Minutes per kilometre when no traffic time is known.
  final int fallbackMinPerKm;

  /// Billable hours in a rental day.
  final int dayHours;

  /// The card every Leca build ships with. Served by /v1/card as well.
  static const builtIn = RateCard(
    id: 'leca-kh-1',
    kinds: {
      'delivery': RateKind(base: 40, perKm: 18, perMin: 2, scaled: false),
      'ride': RateKind(base: 50, perKm: 22, perMin: 3),
      'rent': RateKind(base: 100, perKm: 22, perMin: 3, perHour: 100),
      'rent-self': RateKind(base: 100, perKm: 22, perMin: 0, perHour: 100),
    },
    scales: {
      'bicycle': 70,
      'motorcycle': 100,
      'tuktuk': 130,
      'remorque': 140,
      'car': 180,
      'van6': 220,
      'ambulance': 220,
    },
  );

  /// Cards this build can verify a proof against, by id.
  static final Map<String, RateCard> known = {builtIn.id: builtIn};

  /// The card new quotes are priced on.
  static RateCard active = builtIn;

  /// Adopt a card the server published. Old cards stay known.
  static void adopt(RateCard card) {
    known[card.id] = card;
    active = card;
  }

  int scale(String vehicle) => scales[vehicle] ?? defaultScale;

  int roadMeters(double straightKm) {
    final straight = (straightKm * 1000).round();
    final road = (straight * roadFactor + 500) ~/ 1000;
    return road < minMeters ? minMeters : road;
  }

  int tripMinutes(int meters, int? traffic) {
    if (traffic != null) {
      if (traffic < 1) return 1;
      if (traffic > 1440) return 1440;
      return traffic;
    }
    final estimate = (meters * fallbackMinPerKm + 999) ~/ 1000;
    return estimate < 1 ? 1 : estimate;
  }

  /// Distance and time a quote may publish.
  ///
  /// A claimed road under half the geodesic is ignored. A claimed time is
  /// the time, including a fast one. The card's estimate fills in a missing time.
  ({int meters, int minutes, bool routed}) pricedLeg({
    required double straightKm,
    int? claimedMeters,
    int? claimedMinutes,
  }) {
    final geodesic = (straightKm * 1000).round();
    final floor = geodesic <= 0 ? minMeters : geodesic ~/ 2;
    final claimedOk =
        claimedMeters != null &&
        claimedMeters >= floor &&
        claimedMeters >= minMeters &&
        claimedMeters <= 2000000;
    final meters = claimedOk ? claimedMeters : roadMeters(straightKm);
    final minutes = tripMinutes(meters, claimedMinutes);
    return (meters: meters, minutes: minutes, routed: claimedOk);
  }

  /// What the saved minutes are worth on this card. This is not added to
  /// the passenger fare, and it is not what Leca pays. [companyFastTipCents]
  /// is the amount Leca can fund from its fee.
  ///
  /// The pace has to stay within Sub-decree 86 (8 July 2015) under the
  /// 2015 Law on Road Traffic. In a city or town that is 30 km/h for
  /// motorcycles and tricycles and 40 km/h for cars and vans. On a longer
  /// road it is 60 km/h for a motorcycle of unknown capacity, 40 km/h for
  /// a tricycle, and 80 km/h for a car or van. A trip of 20 km or less is
  /// treated as inside a town. A bicycle has no motor limit in that
  /// sub-decree. A pace over the posted maximum earns nothing.
  int driverBonusCents({
    required String kind,
    required String vehicle,
    required int meters,
    required int actualMinutes,
    bool? inTown,
  }) {
    if (kind != 'delivery' && kind != 'ride' && kind != 'rent') return 0;
    if (meters < 1 || actualMinutes < 1) return 0;
    final average = tripMinutes(meters, null);
    if (actualMinutes >= average) return 0;
    final town = inTown ?? meters <= 20000;
    final limit = _postedLimitKmh(vehicle, inTown: town);
    if (limit == 0) return 0;
    if (limit != null && meters * 60 > limit * 1000 * actualMinutes) {
      return 0;
    }
    final rate =
        kinds[kind] ??
        kinds['delivery'] ??
        const RateKind(base: 40, perKm: 18, perMin: 2);
    final scale = rate.scaled ? this.scale(vehicle) : 100;
    final perMinute = (rate.perMin * scale + 50) ~/ 100;
    if (perMinute <= 0) return 0;
    return (average - actualMinutes) * perMinute;
  }

  /// Cents Leca pays the partner for a fast, legal trip.
  ///
  /// The passenger fare does not include this. It is funded from Leca's
  /// 5% fee, and only up to one fifth of that fee, so four fifths of the
  /// fee still covers the sale. A trip with no room in the fee pays nothing.
  int companyFastTipCents({
    required String kind,
    required String vehicle,
    required int meters,
    required int actualMinutes,
    required int fareCents,
    bool? inTown,
  }) {
    final earned = driverBonusCents(
      kind: kind,
      vehicle: vehicle,
      meters: meters,
      actualMinutes: actualMinutes,
      inTown: inTown,
    );
    if (earned < 1 || fareCents < 1) return 0;
    final fee = (fareCents * 5 + 50) ~/ 100;
    final room = fee ~/ 5;
    if (room < 1) return 0;
    return earned < room ? earned : room;
  }

  /// Null when the vehicle is not a motor vehicle in Sub-decree 86.
  /// Zero when it is not a road vehicle that sub-decree prices.
  int? _postedLimitKmh(String vehicle, {required bool inTown}) {
    final k = vehicle.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (k == 'bicycle' || k == 'bike' || k == 'cycle') return null;
    if (k == 'boat') return 0;
    final trailer =
        (k.contains('motorcycle') && k.contains('trailer')) ||
        k == 'motortrailer';
    final tri =
        k == 'tuktuk' || k == 'tuk' || k == 'remorque' || k == 'tricycle';
    final moto =
        k == 'motorcycle' || k == 'motorbike' || k == 'moto' || trailer;
    final light = k == 'car' || k == 'van6' || k == 'van' || k == 'ambulance';
    if (inTown) {
      if (light && !moto && !tri) return 40;
      return 30;
    }
    if (tri || trailer) return 40;
    if (moto) return 60;
    if (light) return 80;
    return 40;
  }

  /// Hours that are charged for a rental of [hours]: each full day bills
  /// [dayHours], and the remainder bills up to [dayHours].
  int billableHours(int hours) {
    if (hours <= 0) return 0;
    final days = hours ~/ 24;
    final rest = hours % 24;
    return days * dayHours + (rest < dayHours ? rest : dayHours);
  }

  int fareCents({
    required String kind,
    required String vehicle,
    required int meters,
    required int minutes,
    int hours = 0,
  }) {
    final rate =
        kinds[kind] ??
        kinds['delivery'] ??
        const RateKind(base: 40, perKm: 18, perMin: 2);
    final scale = rate.scaled ? this.scale(vehicle) : 100;
    final route =
        rate.base + (meters * rate.perKm + 500) ~/ 1000 + minutes * rate.perMin;
    final time = rate.perHour > 0 ? billableHours(hours) * rate.perHour : 0;
    final raw = route > time ? route : time;
    final scaled = (raw * scale + 50) ~/ 100;
    return scaled < minCents ? minCents : scaled;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kinds': {for (final e in kinds.entries) e.key: e.value.toJson()},
    'scales': scales,
    'defaultScale': defaultScale,
    'minCents': minCents,
    'roadFactor': roadFactor,
    'minMeters': minMeters,
    'fallbackMinPerKm': fallbackMinPerKm,
    'dayHours': dayHours,
  };

  static RateCard? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final rawKinds = raw['kinds'];
    final rawScales = raw['scales'];
    if (id is! String || id.isEmpty || rawKinds is! Map || rawScales is! Map) {
      return null;
    }
    final kinds = <String, RateKind>{};
    for (final e in rawKinds.entries) {
      final kind = RateKind.fromJson(e.value);
      if (kind != null) kinds['${e.key}'] = kind;
    }
    if (kinds.isEmpty) return null;
    final scales = <String, int>{};
    for (final e in rawScales.entries) {
      if (e.value is int) scales['${e.key}'] = e.value as int;
    }
    int pick(String key, int fallback) {
      final v = raw[key];
      return v is int && v > 0 ? v : fallback;
    }

    return RateCard(
      id: id,
      kinds: kinds,
      scales: scales,
      defaultScale: pick('defaultScale', 130),
      minCents: pick('minCents', 50),
      roadFactor: pick('roadFactor', 1300),
      minMeters: pick('minMeters', 500),
      fallbackMinPerKm: pick('fallbackMinPerKm', 3),
      dayHours: pick('dayHours', 8),
    );
  }
}
