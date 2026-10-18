import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leca/catalog.dart';
import 'package:leca/location.dart';
import 'package:leca/market.dart';
import 'package:leca/state.dart';
import 'package:leca/vault.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Future<void> _use(Future<void> Function(LecaState state) body) async {
  final state = LecaState();
  try {
    await body(state);
  } finally {
    state.dispose();
  }
}

Future<void> _bicycle(LecaState state) async {
  expect(
    await state.registerDriver(
      legalName: 'Sokha Meas',
      nameOnId: 'Sokha Meas',
      idNumber: '123456789',
      phone: '012',
      vehicleKind: 'bicycle',
      selfie: _pngA,
      idCard: _pngB,
      independentPartner: true,
      trainedTrafficLaw: true,
      trainedDriving: true,
      trainedService: true,
      trainedConduct: true,
    ),
    'phone_invalid',
  );
  expect(
    await state.registerDriver(
      legalName: 'Sokha Meas',
      nameOnId: 'Sokha Meas',
      idNumber: '123456789',
      phone: '012345678',
      vehicleKind: 'bicycle',
      selfie: _pngA,
      idCard: _pngB,
      independentPartner: true,
      trainedTrafficLaw: true,
      trainedDriving: true,
      trainedService: true,
      trainedConduct: true,
    ),
    isNull,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => TripLocation.override = null);

  test('mock providers, a short password, and an empty handle', () async {
    await _use((state) async {
      for (final method in ['facebook', 'telegram', 'x']) {
        await state.signIn(method: method, handle: 'Ada.Leca@x.test');
        expect(state.session?.method, method);
        expect(state.session?.displayName, 'Ada.Leca');
        expect(state.session?.token, isNull);
        state.signOut();
      }

      await state.signIn(method: 'google', handle: '   ');
      expect(state.authError, 'handle_empty');
      expect(state.signedIn, isFalse);

      await state.signIn(method: 'phone', handle: '1234567');
      expect(state.authError, 'phone_invalid');

      await state.signIn(
        method: 'email',
        handle: 'ada@leca.app',
        password: 'correct-horse',
      );
      expect(state.authError, 'credentials_invalid');
      await state.signIn(
        method: 'email',
        handle: 'ada@leca.app',
        password: 'short',
        register: true,
      );
      expect(state.authError, 'password_short');
      await state.signIn(
        method: 'email',
        handle: 'ada@leca.app',
        password: 'correct-horse',
        name: 'Ada',
        register: true,
      );
      expect(state.session?.displayName, 'Ada');
      await state.signIn(
        method: 'email',
        handle: 'ada@leca.app',
        password: 'correct-horse',
        register: true,
      );
      expect(state.authError, 'email_taken');
      expect(state.session?.displayName, 'Ada');
    });
  });

  test(
    'a bicycle partner goes online, and a second load does not copy jobs',
    () async {
      await _use((state) async {
        await _bicycle(state);
        expect(state.driver?.staffId, 'LECA-KH-456789');
        expect(state.driver?.review, 'local');
        expect(state.setDriving(value: true, note: 'ready'), isNull);
        expect(state.driving, isTrue);
        expect(state.driveNote, 'ready');
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(state.jobs, hasLength(3));
        expect(state.jobs.every((job) => job.usd > 0), isTrue);
        expect(state.nearbyOpenJobs, hasLength(3));
        await state.loadJobs();
        expect(state.jobs, hasLength(3));
        await state.loadJobs(fail: true);
        expect(state.jobsError, 'jobs_failed');
        expect(state.jobs, hasLength(3));
        state.clearDriverError();
        expect(state.driverError, isNull);
      });
    },
  );

  test(
    'a safety report about yourself stops the shift and can be appealed',
    () async {
      await _use((state) async {
        await _bicycle(state);
        state
          ..setBooking(
            const Booking(
              kind: BookKind.send,
              title: 'Parcel',
              amountUsd: 1,
              vehicleId: 'bicycle',
            ),
          )
          ..syncRideMatch();
        expect(state.rideMatch, isNull);
        await state.fileSafetyReport('harassment');
        expect(state.reports, isEmpty);

        state
          ..setBooking(
            const Booking(
              kind: BookKind.ride,
              title: 'Bicycle',
              amountUsd: 1,
              vehicleId: 'bicycle',
            ),
          )
          ..syncRideMatch();
        expect(state.rideMatch?.id, 'LECA-KH-456789');
        expect(state.setDriving(value: true), isNull);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await state.fileSafetyReport('other');
        expect(state.reports, isEmpty);
        await state.fileSafetyReport('violence');
        expect(state.driver?.suspended, isTrue);
        expect(state.driving, isFalse);
        expect(state.reports.single.subjectId, 'LECA-KH-456789');
        expect(state.openPartnerReports, hasLength(1));
        expect(state.rideMatch?.id, isNot('LECA-KH-456789'));
        expect(await state.appealReport('missing', 'no'), 'report_unknown');
        expect(
          await state.appealReport(state.reports.single.id, '  '),
          'appeal_empty',
        );
        expect(
          await state.appealReport(state.reports.single.id, ' I was walking '),
          isNull,
        );
        expect(state.reports.single.status, 'appealed');
        expect(state.reports.single.appeal, 'I was walking');
        expect(state.suspendedPartnerIds, contains('LECA-KH-456789'));
      });
    },
  );

  test(
    'moving the drop-off changes the delivery key, and a bad city does not',
    () async {
      await _use((state) async {
        final kitchen = Catalog.kitchen('nom_banh_chok');
        final here = state.deliveryFareKey(kitchen);
        state.deliverToCity('kep');
        expect(state.deliveryFareKey(kitchen), isNot(here));
        expect(state.deliveryQuoteOf(kitchen).checksOut, isTrue);
        expect(state.deliveryQuoteOf(kitchen).kilometres, greaterThan(10));

        state.setCity('atlantis');
        expect(() => state.city, throwsStateError);
        state.setCity('phnom_penh');
        expect(state.city.nameEn, 'Phnom Penh');

        state.setRail('nope');
        expect(state.railId, 'nope');
        expect(state.rail.id, 'aba');
        state.setWindow(PopularWindow.month);
        expect(state.window, PopularWindow.month);
        state.setNote('no chilli');
        expect(state.note, 'no chilli');
        state.clearSupplyError();
        expect(state.supplyError, isNull);
      });
    },
  );

  test(
    'reply samples average the in-hours answers and ignore the night',
    () async {
      await _use((state) async {
        const place = 'shop';
        final morning = DateTime(2026, 10, 18, 9);
        state.sendMessage(
          placeId: place,
          text: 'open?',
          asBusiness: true,
          at: morning,
        );
        expect(state.replySecondsFor(place), isNull);

        state
          ..sendMessage(
            placeId: place,
            text: 'hello',
            asBusiness: false,
            at: morning,
          )
          ..sendMessage(
            placeId: place,
            text: 'yes',
            asBusiness: true,
            at: morning.add(const Duration(minutes: 1)),
          )
          ..sendMessage(
            placeId: place,
            text: 'and soup?',
            asBusiness: false,
            at: morning.add(const Duration(minutes: 2)),
          )
          ..sendMessage(
            placeId: place,
            text: 'yes',
            asBusiness: true,
            at: morning.add(const Duration(minutes: 6)),
          );
        expect(state.replySecondsFor(place), 150);

        final night = DateTime(2026, 10, 18, 22);
        state
          ..sendMessage(
            placeId: place,
            text: 'tonight?',
            asBusiness: false,
            at: night,
          )
          ..sendMessage(
            placeId: place,
            text: 'tomorrow',
            asBusiness: true,
            at: night.add(const Duration(hours: 2)),
          );
        expect(state.replySecondsFor(place), 150);
        expect(state.owns(place), isFalse);
      });
    },
  );

  test('a shop, a vehicle, and a driver survive the vault', () async {
    final vault = MemoryVault();
    final first = LecaState(vault: vault);
    try {
      await _bicycle(first);
      expect(first.setDriving(value: true), isNull);
      await first.openBusiness(
        kind: 'pharmacy',
        name: 'Tiny',
        sellerName: 'Ada',
        sellerPhone: '012345678',
        sellerId: '123456',
      );
      final business = first.businesses.single.id;
      expect(
        first.addItem(
          businessId: business,
          description: '  ភួយ  ',
          usd: 4,
          photo: _pngA,
        ),
        isNull,
      );
      await first.listVehicle(
        kind: 'boat',
        withDriver: true,
        autonomous: false,
        owner: true,
        note: 'Kep',
      );
      first.fileConsumerReport(business, 'late');
      await first.save();

      final second = LecaState(vault: vault);
      try {
        await second.restore();
        expect(second.driver?.vehicleKind, 'bicycle');
        expect(second.driving, isTrue);
        expect(second.businesses.single.name, 'Tiny');
        expect(second.itemsFor(business).single.description, 'ភួយ');
        expect(second.vehicles.single.kind, 'boat');
        expect(second.vehicles.single.note, 'Kep');
        expect(second.reports.single.kind, 'consumer');
        second.takeDownItem(second.items.single.id);
        expect(second.itemsFor(business), isEmpty);
        expect(second.reports.map((report) => report.kind), [
          'consumer',
          'takedown',
        ]);
      } finally {
        second.dispose();
      }
    } finally {
      first.dispose();
    }
  });

  test('the phone vault keeps one document between reads', () async {
    SharedPreferences.setMockInitialValues({});
    const vault = PrefsVault(key: 'leca.test.document');
    expect(await vault.read(), isNull);
    await vault.write('{"v":1}');
    expect(await vault.read(), '{"v":1}');
    await vault.write('{"v":2}');
    expect(await vault.read(), '{"v":2}');
  });

  test(
    'a copied selfie is rejected before the partner file is stored',
    () async {
      await _use((state) async {
        expect(
          await state.registerDriver(
            legalName: 'Ada',
            nameOnId: 'Ada',
            idNumber: '123456',
            phone: '012345678',
            vehicleKind: 'bicycle',
            selfie: _pngA,
            idCard: _pngA,
            independentPartner: true,
            trainedTrafficLaw: true,
            trainedDriving: true,
            trainedService: true,
            trainedConduct: true,
          ),
          'photo_same',
        );
        expect(state.driver, isNull);
        state.clearDriverError();
        expect(state.driverError, isNull);
      });
    },
  );

  test('every province, kitchen, and rail is a real Cambodia row', () {
    final cities = MarketConfig.cambodia.cities;
    expect(cities.map((city) => city.id).toSet(), hasLength(cities.length));
    for (final city in cities) {
      expect(city.latitude, inInclusiveRange(9, 15));
      expect(city.longitude, inInclusiveRange(102, 108));
      expect(city.nameKm, isNotEmpty);
      expect(city.nameEn, isNotEmpty);
    }

    for (final kitchen in Catalog.kitchens) {
      expect(cities.map((city) => city.id), contains(kitchen.cityId));
      expect(kitchen.menu, isNotEmpty);
      expect(kitchen.rating, inInclusiveRange(1, 5));
      for (final dish in kitchen.menu) {
        expect(dish.usd, greaterThan(0));
        expect(dish.nameKm, isNotEmpty);
        expect(kitchen.dish(dish.id).id, dish.id);
      }
    }

    for (final pick in Catalog.popular) {
      final kitchen = Catalog.kitchen(pick.kitchenId);
      expect(kitchen.cityId, pick.cityId);
      expect(kitchen.menu.map((dish) => dish.id), contains(pick.dishId));
      expect(pick.orders, greaterThan(0));
    }

    final rails = MarketConfig.cambodia.rails;
    expect(rails.map((rail) => rail.id).toSet(), hasLength(rails.length));
    final khqr = rails.where((rail) => rail.kind == RailKind.khqr);
    expect(khqr, hasLength(4));
    for (final rail in khqr) {
      expect(rail.bakongAccountId, contains('@'));
      expect(rail.acquiringBank, isNotEmpty);
    }
    expect(
      MarketConfig.cambodia.exampleVehicles.every((offer) => !offer.autonomous),
      isTrue,
    );
  });

  test('a trip share without a partner still names the audience', () async {
    await _use((state) async {
      TripLocation.override = () async =>
          const TripFix(latitude: 10.4829, longitude: 104.3167);
      state.deliverToCity('kep');
      final text = await state.shareTrip('family');
      expect(text, contains('City: Kep'));
      expect(text, contains('Driver: -'));
      expect(text, contains('For: family'));
      expect(state.shares.single.hasLocation, isTrue);
      expect(state.shares.single.audience, 'family');
    });
  });
}
