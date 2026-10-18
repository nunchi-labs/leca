import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leca/geo.dart';
import 'package:leca/location.dart';
import 'package:leca/market.dart';
import 'package:leca/quote.dart';
import 'package:leca/rate.dart';
import 'package:leca/traffic.dart';

void main() {
  tearDown(() {
    RateCard.known.removeWhere((id, _) => id != RateCard.builtIn.id);
    RateCard.active = RateCard.builtIn;
  });

  test('the app and the server keep one rate card', () {
    expect(
      File('lib/rate_card.dart').readAsStringSync(),
      File('server/lib/rate_card.dart').readAsStringSync(),
    );
  });

  test('the built-in card prices every kind and keeps a 50 cent floor', () {
    const card = RateCard.builtIn;
    expect(card.id, 'leca-kh-1');
    expect(card.kinds.keys, ['delivery', 'ride', 'rent', 'rent-self']);
    expect(card.scale('bicycle'), 70);
    expect(card.scale('motorcycle'), 100);
    expect(card.scale('tuktuk'), 130);
    expect(card.scale('remorque'), 140);
    expect(card.scale('car'), 180);
    expect(card.scale('van6'), 220);
    expect(card.scale('boat'), card.defaultScale);

    // Delivery is not scaled, so the vehicle does not change it.
    expect(
      fareCents(kind: 'delivery', vehicle: 'car', meters: 2000, minutes: 10),
      fareCents(
        kind: 'delivery',
        vehicle: 'bicycle',
        meters: 2000,
        minutes: 10,
      ),
    );
    expect(
      fareCents(kind: 'parcel', vehicle: 'car', meters: 2000, minutes: 10),
      96,
    );

    // 5 km and 10 minutes, then each vehicle's percent.
    expect(
      [
        fareCents(kind: 'ride', vehicle: 'bicycle', meters: 5000, minutes: 10),
        fareCents(
          kind: 'ride',
          vehicle: 'motorcycle',
          meters: 5000,
          minutes: 10,
        ),
        fareCents(kind: 'ride', vehicle: 'tuktuk', meters: 5000, minutes: 10),
        fareCents(kind: 'ride', vehicle: 'remorque', meters: 5000, minutes: 10),
        fareCents(kind: 'ride', vehicle: 'car', meters: 5000, minutes: 10),
        fareCents(kind: 'ride', vehicle: 'van6', meters: 5000, minutes: 10),
        fareCents(kind: 'ride', vehicle: 'boat', meters: 5000, minutes: 10),
      ],
      [133, 190, 247, 266, 342, 418, 247],
    );

    // A short bicycle ride would be 35 cents before the floor.
    expect(
      fareCents(kind: 'ride', vehicle: 'bicycle', meters: 0, minutes: 0),
      50,
    );
    expect(fareCents(kind: 'delivery', vehicle: '', meters: 0, minutes: 0), 50);
  });

  test('a rental day is eight hours, and that charge floors a short route', () {
    final card = RateCard.builtIn;
    expect([0, 1, 8, 9, 23, 24, 25, 47, 48].map(card.billableHours).toList(), [
      0,
      1,
      8,
      8,
      8,
      8,
      9,
      16,
      16,
    ]);

    // One hour of a motorcycle is the route, not the one hour of time.
    expect(
      fareCents(
        kind: 'rent',
        vehicle: 'motorcycle',
        meters: 100000,
        minutes: 60,
        hours: 1,
      ),
      2480,
    );
    // A day that ends where it started still bills eight hours.
    expect(
      fareCents(
        kind: 'rent',
        vehicle: 'car',
        meters: 500,
        minutes: 1,
        hours: 24,
      ),
      1440,
    );
    // Self-drive does not bill minutes, so a waiting clock does not raise it.
    expect(
      fareCents(
        kind: 'rent-self',
        vehicle: 'car',
        meters: 2000,
        minutes: 0,
        hours: 0,
      ),
      fareCents(
        kind: 'rent-self',
        vehicle: 'car',
        meters: 2000,
        minutes: 100,
        hours: 0,
      ),
    );
  });

  test('a legal pace under the average pays the driver more', () {
    const card = RateCard.builtIn;
    // 5 km at the card average is 15 minutes, which is 20 km/h.
    expect(card.tripMinutes(5000, null), 15);

    // 30 km/h on a motorcycle in town is the posted limit, and it is
    // faster than 20 km/h, so the saved minutes are paid.
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 5000,
        actualMinutes: 10,
      ),
      15,
    );

    // 60 km/h is over the 30 km/h town limit. The passenger still
    // arrives, and the partner earns no extra.
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 5000,
        actualMinutes: 5,
      ),
      0,
    );

    // A car in town may do 40 km/h. 30 km/h is inside that, scaled.
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'car',
        meters: 5000,
        actualMinutes: 10,
      ),
      25,
    );
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'car',
        meters: 5000,
        actualMinutes: 5,
      ),
      0,
    );

    // Matching the average, self-drive, and a boat earn nothing.
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 5000,
        actualMinutes: 15,
      ),
      0,
    );
    expect(
      card.driverBonusCents(
        kind: 'rent-self',
        vehicle: 'car',
        meters: 5000,
        actualMinutes: 10,
      ),
      0,
    );
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'boat',
        meters: 5000,
        actualMinutes: 10,
      ),
      0,
    );

    // On a long road a motorcycle may do 60 km/h. 50 km/h beats the
    // average and stays inside the limit. The card values those minutes.
    // Leca pays only the part that fits in one fifth of its fee.
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 100000,
        actualMinutes: 120,
        inTown: false,
      ),
      greaterThan(0),
    );
    expect(
      card.driverBonusCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 100000,
        actualMinutes: 80,
        inTown: false,
      ),
      0,
    );
  });

  test('Leca funds a fast tip from its fee, not the passenger fare', () {
    const card = RateCard.builtIn;
    final fare = card.fareCents(
      kind: 'ride',
      vehicle: 'motorcycle',
      meters: 5000,
      minutes: 10,
    );
    final earned = card.driverBonusCents(
      kind: 'ride',
      vehicle: 'motorcycle',
      meters: 5000,
      actualMinutes: 10,
    );
    final tip = card.companyFastTipCents(
      kind: 'ride',
      vehicle: 'motorcycle',
      meters: 5000,
      actualMinutes: 10,
      fareCents: fare,
    );
    final fee = (fare * 5 + 50) ~/ 100;
    expect(earned, 15);
    expect(fee, greaterThan(tip));
    expect(tip, fee ~/ 5);
    expect(tip, lessThan(earned));
    expect(
      card.companyFastTipCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 5000,
        actualMinutes: 5,
        fareCents: fare,
      ),
      0,
    );
    expect(
      card.companyFastTipCents(
        kind: 'ride',
        vehicle: 'motorcycle',
        meters: 5000,
        actualMinutes: 10,
        fareCents: 50,
      ),
      0,
    );
    final longFare = card.fareCents(
      kind: 'ride',
      vehicle: 'motorcycle',
      meters: 100000,
      minutes: 120,
    );
    final longTip = card.companyFastTipCents(
      kind: 'ride',
      vehicle: 'motorcycle',
      meters: 100000,
      actualMinutes: 120,
      fareCents: longFare,
      inTown: false,
    );
    final longFee = (longFare * 5 + 50) ~/ 100;
    expect(longTip, longFee ~/ 5);
    expect(longTip, lessThan(longFee));
  });

  test('road metres and traffic minutes stay inside the card', () {
    final card = RateCard.builtIn;
    expect(card.roadMeters(0), 500);
    expect(card.roadMeters(0.2), 500);
    expect(card.roadMeters(1), 1300);
    expect(card.roadMeters(1.234), 1604);

    expect(card.tripMinutes(100, null), 1);
    expect(card.tripMinutes(1000, null), 3);
    expect(card.tripMinutes(1000, 0), 1);
    expect(card.tripMinutes(1000, 12), 12);
    expect(card.tripMinutes(1000, 2000), 1440);

    final walked = priceTrip(
      kind: 'delivery',
      fromLat: 11.5564,
      fromLng: 104.9282,
      toLat: 11.5564,
      toLng: 104.9282,
    );
    expect(walked.routed, isFalse);
    expect(walked.meters, 500);
    expect(walked.minutes, 2);
    expect(walked.cents, 53);
    expect(walked.checksOut, isTrue);

    final short = priceTrip(
      kind: 'ride',
      vehicle: 'car',
      fromLat: 11.5,
      fromLng: 104.9,
      toLat: 11.55,
      toLng: 104.92,
      routeMeters: 499,
      traffic: 4,
    );
    expect(short.routed, isFalse);
    expect(short.meters, isNot(499));

    final driven = priceTrip(
      kind: 'ride',
      vehicle: 'car',
      fromLat: 11.5,
      fromLng: 104.9,
      toLat: 11.55,
      toLng: 104.92,
      routeMeters: 5000,
      traffic: 90,
    );
    expect(driven.routed, isTrue);
    expect(driven.meters, 5000);
    expect(driven.minutes, 90);
  });

  test('a quote checks out on the card it names, and a bad one is dropped', () {
    final quote = priceTrip(
      kind: 'ride',
      vehicle: 'tuktuk',
      fromLat: 11.55,
      fromLng: 104.92,
      toLat: 11.56,
      toLng: 104.93,
    );
    final again = TripQuote.fromJson(quote.toJson());
    expect(again?.proof, quote.proof);
    expect(again?.cents, quote.cents);

    final tampered = quote.toJson()..['cents'] = quote.cents + 1;
    expect(TripQuote.fromJson(tampered), isNull);
    expect(TripQuote.fromJson('nope'), isNull);
    expect(TripQuote.fromJson({'meters': 1}), isNull);

    final published = {
      'card': 'leca-kh-9',
      'kind': 'delivery',
      'vehicle': '',
      'meters': 0,
      'minutes': 0,
      'hours': 0,
      'cents': 1,
      'proof': '0' * 64,
      'rates': {
        'id': 'leca-kh-9',
        'kinds': {
          'delivery': {'base': 1, 'perKm': 0, 'perMin': 0, 'scaled': false},
        },
        'scales': <String, int>{},
      },
    };
    expect(TripQuote.fromJson(published), isNull);
    expect(RateCard.active.id, 'leca-kh-9');
    expect(RateCard.known['leca-kh-1'], isNotNull);

    published['cents'] = 50;
    published['proof'] = fareProof(
      fareBody(
        kind: 'delivery',
        vehicle: '',
        meters: 0,
        minutes: 0,
        cents: 50,
        card: 'leca-kh-9',
      ),
    );
    final adopted = TripQuote.fromJson(published);
    expect(adopted?.checksOut, isTrue);
    expect(adopted?.cents, 50);
  });

  test('a card that is not a card is refused, and zeros fall back', () {
    expect(RateKind.fromJson({'base': 40.0, 'perKm': 18, 'perMin': 2}), isNull);
    expect(RateCard.fromJson(null), isNull);
    expect(
      RateCard.fromJson({
        'id': '',
        'kinds': <String, Object?>{},
        'scales': <String, Object?>{},
      }),
      isNull,
    );
    expect(
      RateCard.fromJson({
        'id': 'x',
        'kinds': {'nope': 'nope'},
        'scales': <String, Object?>{},
      }),
      isNull,
    );

    final card = RateCard.fromJson({
      'id': 'x',
      'kinds': {
        'delivery': {'base': 1, 'perKm': 0, 'perMin': 0},
      },
      'scales': {'car': 180, 'bad': 'no'},
      'minCents': 0,
      'roadFactor': -1,
      'dayHours': 0,
    });
    expect(card, isNotNull);
    expect(card!.minCents, 50);
    expect(card.roadFactor, 1300);
    expect(card.dayHours, 8);
    expect(card.scales, {'car': 180});
    expect(card.kinds['delivery']!.scaled, isTrue);
    expect(card.toJson()['id'], 'x');

    final round = RateCard.fromJson(RateCard.builtIn.toJson());
    expect(round!.id, RateCard.builtIn.id);
    expect(
      round.fareCents(kind: 'ride', vehicle: 'car', meters: 2000, minutes: 10),
      RateCard.builtIn.fareCents(
        kind: 'ride',
        vehicle: 'car',
        meters: 2000,
        minutes: 10,
      ),
    );
  });

  test('Phnom Penh, Siem Reap, Kampot, and Kep sit where the map says', () {
    final pp = MarketConfig.cambodia.city('phnom_penh');
    final sr = MarketConfig.cambodia.city('siem_reap');
    final kampot = MarketConfig.cambodia.city('kampot');
    final kep = MarketConfig.cambodia.city('kep');

    expect(kmBetween(pp.latitude, pp.longitude, pp.latitude, pp.longitude), 0);
    final north = northOf(
      TripFix(latitude: pp.latitude, longitude: pp.longitude),
      1,
    );
    expect(
      kmBetween(pp.latitude, pp.longitude, north.latitude, north.longitude),
      closeTo(1, 0.02),
    );
    expect(north.longitude, pp.longitude);

    final toSiemReap = kmBetween(
      pp.latitude,
      pp.longitude,
      sr.latitude,
      sr.longitude,
    );
    final toKep = kmBetween(
      kampot.latitude,
      kampot.longitude,
      kep.latitude,
      kep.longitude,
    );
    expect(toSiemReap, inInclusiveRange(220, 250));
    expect(toKep, inInclusiveRange(15, 30));
    expect(toSiemReap, greaterThan(toKep));
  });

  test('the fee is 5 percent of the cents, and riel follows 4100', () {
    expect(saleFeeUsd(1.25), 0.06);
    expect(saleFeeUsd(0.09), 0);
    expect(saleFeeUsd(0.10), 0.01);
    expect(saleFeeUsd(-3), 0);
    expect(moneyUsd(2.5), r'$2.50');
    expect(moneyKhr(2.5), '៛10250');
    expect(moneyKhr(0), '៛0');
  });

  test('reply time counts from 08:00 and stops at 21:00', () {
    final open = DateTime(2026, 10, 18, 8);
    final shut = DateTime(2026, 10, 18, 21);
    expect(isWorkingHour(open), isTrue);
    expect(isWorkingHour(shut), isFalse);
    expect(isWorkingHour(DateTime(2026, 10, 18, 7, 59)), isFalse);
    expect(averageSeconds(const []), isNull);
    expect(averageSeconds(const [1, 2]), 1);
    expect(
      inHoursDelay(
        asked: open,
        replied: open.subtract(const Duration(seconds: 1)),
      ),
      isNull,
    );
    expect(
      inHoursDelay(asked: open, replied: open.add(const Duration(minutes: 5))),
      fastReplySeconds,
    );
  });

  test(
    'routes and the rate card stay empty until a server is configured',
    () async {
      const here = TripFix(latitude: 11.55, longitude: 104.92);
      const there = TripFix(latitude: 11.56, longitude: 104.93);
      expect(await fetchRateCard(), isNull);
      expect(await roadRoute(from: here, to: there), isNull);
      expect(await trafficMinutes(from: here, to: there), isNull);
    },
  );
}
