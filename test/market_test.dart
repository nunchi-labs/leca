import 'package:flutter_test/flutter_test.dart';
import 'package:leca/catalog.dart';
import 'package:leca/compliance.dart';
import 'package:leca/market.dart';
import 'package:leca/state.dart';

void main() {
  test('every sale adds a 5 percent fee', () {
    expect(saleFeeUsd(1.80), 0.09);
    expect(saleFeeUsd(0), 0);
    final state = LecaState()
      ..setBooking(
        const Booking(
          kind: BookKind.ride,
          title: 'Moto',
          amountUsd: 1.80,
          vehicleId: 'moto',
        ),
      );
    expect(state.saleUsd, 1.80);
    expect(state.feeUsd, 0.09);
    expect(state.totalUsd, 1.89);
    state.setTip(0.50);
    expect(state.tipUsd, 0.50);
    expect(state.totalUsd, 2.39);
    state.setTip(0);
    expect(state.totalUsd, 1.89);
  });

  test('a plain motorcycle is the first ride, not a tuk-tuk', () {
    final rides = MarketConfig.cambodia.regularVehicles;
    expect(rides.first.id, 'motorcycle');
    expect(CambodiaRules.isMotorcycle('motorcycle'), isTrue);
    expect(CambodiaRules.isTricycle('motorcycle'), isFalse);
    expect(CambodiaRules.isMotorcycleWithTrailer('motorcycle'), isFalse);
    expect(rides.map((offer) => offer.id), contains('tuktuk'));
  });

  test('any legal vehicle is another offer, not an enum case', () {
    const extra = VehicleOffer(
      id: 'boat',
      nameKm: 'ទូក',
      nameEn: 'Boat',
      withDriver: true,
      selfDrive: true,
    );
    final listed = [...MarketConfig.cambodia.exampleVehicles, extra];
    expect(listed.map((v) => v.id), containsAll(['tuktuk', 'boat']));
    expect(listed.map((v) => v.id), isNot(contains('robotaxi')));
    expect(
      MarketConfig.cambodia.exampleVehicles.map((v) => v.id),
      isNot(contains('robotaxi')),
    );
  });

  test(
    'Cambodia is the test market with ABA default and extra KH QR rails',
    () {
      expect(MarketConfig.current.isTestMarket, isTrue);
      expect(MarketConfig.current.defaultRailId, 'aba');
      expect(
        MarketConfig.current.rails.map((r) => r.id),
        containsAll([
          'aba',
          'bakong',
          'acleda',
          'wingbank',
          'cash',
          'visa',
          'mastercard',
          'discover',
          'unionpay',
          'alipay',
        ]),
      );
      expect(MarketConfig.current.rails.map((r) => r.kind).toSet(), {
        RailKind.khqr,
        RailKind.cash,
        RailKind.stripe,
      });
      expect(MarketConfig.current.autonomousVehicles, isEmpty);
    },
  );

  test('Cambodia is the only market and wheels can be bought or rented', () {
    expect(MarketConfig.active.countryCode, 'KH');
    expect(MarketConfig.active.currencyCode, 'USD');
    expect(MarketConfig.active.cities, hasLength(25));
    expect(MarketConfig.active.cities.first.id, 'phnom_penh');
    expect(
      MarketConfig.active.cities.map((c) => c.id),
      contains('tboung_khmum'),
    );
    final here = LecaState();
    final toulTomPoung = Catalog.kitchens.firstWhere(
      (k) => k.id == 'nom_banh_chok',
    );
    final angkor = Catalog.kitchens.firstWhere((k) => k.id == 'angkor_khmer');
    expect(here.covers(toulTomPoung.latitude, toulTomPoung.longitude), isTrue);
    expect(here.covers(angkor.latitude, angkor.longitude), isFalse);
    here.setRadius(1);
    expect(here.covers(toulTomPoung.latitude, toulTomPoung.longitude), isFalse);
    here.setRadius(LecaState.countryWide);
    expect(here.wholeCountry, isTrue);
    expect(here.covers(angkor.latitude, angkor.longitude), isTrue);
    final wheels = MarketConfig.cambodia.exampleVehicles;
    expect(
      wheels.map((v) => v.id),
      containsAll(['car', 'motorcycle', 'bicycle', 'tuktuk']),
    );
    final bicycle = wheels.firstWhere((v) => v.id == 'bicycle');
    expect(bicycle.salePrice, 80);
    expect(bicycle.rentPrice, 3);
    expect(bicycle.usd, 0.80);
  });
}
