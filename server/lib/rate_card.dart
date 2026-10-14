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
