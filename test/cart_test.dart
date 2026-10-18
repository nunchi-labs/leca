import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:leca/auth.dart';
import 'package:leca/catalog.dart';
import 'package:leca/location.dart';
import 'package:leca/market.dart';
import 'package:leca/quote.dart';
import 'package:leca/state.dart';
import 'package:leca/talk.dart';
import 'package:leca/vault.dart';

Future<void> _use(Future<void> Function(LecaState state) body) async {
  final state = LecaState();
  try {
    await body(state);
  } finally {
    state.dispose();
  }
}

void main() {
  tearDown(() {
    RateCard.known.removeWhere((id, _) => id != RateCard.builtIn.id);
    RateCard.active = RateCard.builtIn;
    TripLocation.override = null;
  });

  test(
    'a second kitchen replaces the cart, and checkout adds the fee',
    () async {
      await _use((state) async {
        final morning = Catalog.kitchen('nom_banh_chok');
        final angkor = Catalog.kitchen('angkor_khmer');
        final noodles = morning.dish('nbc_khmer');
        final amok = angkor.dish('amok');

        state
          ..addDish(noodles, morning)
          ..addDish(noodles, morning);
        expect(state.countOf(noodles.id), 2);
        expect(state.subtotalUsd, 5);
        expect(state.payableLabel, morning.nameEn);

        state.addDish(amok, angkor);
        expect(state.countOf(noodles.id), 0);
        expect(state.countOf(amok.id), 1);
        expect(state.cartKitchen?.id, angkor.id);
        expect(state.subtotalUsd, 4.25);
        expect(state.deliveryUsd, greaterThan(0));
        expect(state.feeUsd, saleFeeUsd(state.saleUsd));
        expect(state.totalUsd, closeTo(state.saleUsd + state.feeUsd, 0.001));

        state.removeDish(amok);
        expect(state.itemCount, 0);
        expect(state.cartKitchen, isNull);
        expect(state.deliveryUsd, 0);
        expect(state.hasPayable, isFalse);

        state
          ..addDish(noodles, morning)
          ..setNote('no chilli')
          ..setRail('cash')
          ..setBooking(
            const Booking(kind: BookKind.send, title: 'Parcel', amountUsd: 1.5),
          );
        expect(state.itemCount, 0);
        expect(state.hasPayable, isTrue);
        expect(state.payableLabel, 'Parcel');
        expect(state.saleUsd, 1.5);
        expect(state.feeUsd, 0.08);

        state.clearCart();
        expect(state.booking, isNull);
        expect(state.note, isEmpty);
        expect(state.railId, 'aba');
        expect(state.hasPayable, isFalse);
      });
    },
  );

  test('radius, city, and the phone fix decide what is nearby', () async {
    await _use((state) async {
      expect(state.radiusKm, 10);
      state.setRadius(0);
      expect(state.radiusKm, 1);
      state.setRadius(1000);
      expect(state.radiusKm, LecaState.countryWide);
      expect(state.wholeCountry, isTrue);
      state.setRadius(10);
      expect(state.radiusKm, 10);

      state.deliverToCity('kep');
      final kep = MarketConfig.cambodia.city('kep');
      expect(state.cityId, 'kep');
      expect(state.here?.latitude, kep.latitude);
      expect(state.covers(kep.latitude, kep.longitude), isTrue);

      state.toggleLocale();
      expect(state.locale.languageCode, 'en');
      state.toggleLocale();
      expect(state.locale.languageCode, 'km');

      TripLocation.override = () async =>
          const TripFix(latitude: 13.0957, longitude: 103.2022);
      await state.loadHere();
      expect(state.cityId, 'battambang');

      TripLocation.override = () async => null;
      final before = state.cityId;
      await state.loadHere();
      expect(state.cityId, before);
    });
  });

  test('open jobs inside the radius can be taken or declined', () async {
    await _use((state) async {
      await state.loadJobs();
      expect(state.jobsError, 'jobs_offline');
      expect(state.jobs, isEmpty);

      const near = OperatorJob(
        id: 'near',
        kind: 'food',
        titleKm: 'ក្បែរ',
        titleEn: 'Near',
        detailKm: 'ភ្នំពេញ',
        detailEn: 'Phnom Penh',
        usd: 1.2,
      );
      const far = OperatorJob(
        id: 'far',
        kind: 'ride',
        titleKm: 'ឆ្ងាយ',
        titleEn: 'Far',
        detailKm: 'សៀមរាប',
        detailEn: 'Siem Reap',
        usd: 4,
        latitude: 13.3633,
        longitude: 103.8564,
        room: 'ride:1',
      );
      state.jobs.addAll([near, far]);
      expect(state.nearbyOpenJobs.map((job) => job.id), ['near']);
      expect(far.talkRoom, 'ride:1');
      expect(near.talkRoom, 'job:near');
      expect(near.titleFor(km: true), 'ក្បែរ');
      expect(near.detailFor(km: false), 'Phnom Penh');

      state.setRadius(LecaState.countryWide);
      expect(
        state.nearbyOpenJobs.map((job) => job.id),
        containsAll(['near', 'far']),
      );
      state
        ..declineJob('near')
        ..acceptJob('far')
        ..acceptJob('missing');
      expect(state.openJobs, isEmpty);
      expect(state.acceptedJobs.single.id, 'far');
      expect(state.driving, isFalse);
      expect(state.fareSide, 'customer');
      state.driving = true;
      expect(state.fareSide, 'driver');
    });
  });

  test(
    'a bid rounds to cents, and an unknown wheel has a stand-in price',
    () async {
      await _use((state) async {
        state
          ..proposeFare('ride:boat', 4, 0)
          ..proposeFare('ride:boat', 4, -1);
        expect(state.askFor('ride:boat'), isNull);

        state.proposeFare('ride:boat', 4, 1.236, proposer: 'shop');
        expect(state.askFor('ride:boat')?.pending?.usd, 1.24);
        expect(state.askFor('ride:boat')?.pending?.side, 'driver');
        expect(state.payable('ride:boat', 4), 4);

        const known = ListedVehicle(
          id: 'v1',
          kind: 'Bicycle',
          withDriver: false,
          autonomous: false,
        );
        const unknown = ListedVehicle(
          id: 'v2',
          kind: 'oxcart',
          withDriver: true,
          autonomous: false,
        );
        expect(state.listedPrice(known, sale: true), 80);
        expect(state.listedPrice(known, sale: false), 3);
        expect(state.listedPrice(unknown, sale: true), 100);
        expect(state.listedPrice(unknown, sale: false), 6);
        expect(state.newOrderId(), matches(RegExp(r'^LECA\d{8}$')));

        final van = MarketConfig.cambodia.exampleVehicles.firstWhere(
          (offer) => offer.id == 'van6',
        );
        expect(van.rentPrice, 7);
        expect(van.salePrice, 1200);
      });
    },
  );

  test('the popular dish follows the window, then any city', () async {
    expect(
      Catalog.popularIn('phnom_penh', PopularWindow.week)?.dishId,
      'beef_pepper',
    );
    expect(Catalog.popularIn('siem_reap', PopularWindow.day)?.dishId, 'amok');
    expect(
      Catalog.popularIn('kampot', PopularWindow.hour)?.kitchenId,
      'nom_banh_chok',
    );
    expect(
      Catalog.popularNear(const [
        'old_market_cafe',
      ], PopularWindow.week)?.dishId,
      'num_paen',
    );
    expect(Catalog.popularNear(const ['missing'], PopularWindow.hour), isNull);

    final kitchen = Catalog.kitchen('nom_banh_chok');
    expect(kitchen.serves('kep'), isTrue);
    expect(kitchen.dish('orange').nameFor(LocaleCode.en), 'Khmer orange juice');
    expect(() => kitchen.dish('missing'), throwsA(isA<StateError>()));

    const local = Kitchen(
      id: 'kep_only',
      cityId: 'kep',
      nameKm: 'កែប',
      nameEn: 'Kep',
      areaKm: 'កែប',
      areaEn: 'Kep',
      latitude: 10.48,
      longitude: 104.32,
      etaMin: 10,
      deliveryUsd: 0.4,
      rating: 4,
      menu: [],
      nationwide: false,
    );
    expect(local.serves('kep'), isTrue);
    expect(local.serves('phnom_penh'), isFalse);

    expect(await Catalog.load(), Catalog.kitchens);
    await expectLater(
      Catalog.load(fail: true),
      throwsA(isA<CatalogException>()),
    );
  });

  test('chat clips the line, binds who, and refuses a broken link', () async {
    await _use((state) async {
      final at = DateTime.utc(2026, 1, 2, 3, 4, 5, 6);
      expect(talkStamp(at), '2026-01-02T03:04:05.006Z');
      expect(talkWho(''), isEmpty);
      expect(talkWho('phone:1'), matches(RegExp(r'^[0-9a-f]{16}$')));

      final messy = talkAppend(
        prior: const [],
        room: 'shop',
        kind: 'sticker',
        name: '  ${'Ada' * 20}\n',
        who: 'abc123' * 5,
        at: at,
        text: '  hello\n\nthere   ',
      );
      expect(messy.kind, 'text');
      expect(messy.name.length, 24);
      expect(messy.who.length, 16);
      expect(messy.text, 'hello there');
      expect(messy.checksOut, isTrue);

      final guest = talkAppend(
        prior: const [],
        room: 'shop',
        kind: 'text',
        name: ' \n ',
        at: at,
        text: 'ok',
      );
      expect(guest.name, 'Guest');

      final second = talkAppend(
        prior: [messy],
        room: 'shop',
        kind: 'text',
        name: 'Bo',
        at: at,
        text: 'next',
      );
      expect(talkChecks([messy, second]), isTrue);
      expect(talkChecks([second, messy]), isFalse);
      expect(
        talkChecks([
          TalkLine(
            seq: 2,
            room: messy.room,
            kind: messy.kind,
            name: messy.name,
            at: messy.at,
            text: messy.text,
            prev: messy.prev,
            proof: messy.proof,
          ),
        ]),
        isFalse,
      );
      expect(TalkLine.fromJson({'seq': 0}), isNull);
      expect(TalkLine.fromJson('nope'), isNull);
      final parsed = TalkLine.fromJson({
        'seq': 1,
        'room': 'a\nb',
        'kind': 'text',
        'name': 'Ada',
        'at': messy.at,
        'text': 'hi',
        'prev': '',
        'proof': 'x',
      });
      expect(parsed?.room, 'a b');
      expect(parsed?.checksOut, isFalse);

      expect(
        PriceLine.parse('allow 1.50 customer')?.encode(),
        'allow 1.50 customer',
      );
      expect(PriceLine.parse('ask 1.2 driver')?.usd, 1.2);
      expect(PriceLine.parse('end 0.00 driver')?.verb, 'end');
      expect(PriceLine.parse('ask  2.40 driver'), isNull);
      expect(PriceLine.parse('ask -1.00 driver'), isNull);
      expect(PriceLine.parse('ask 1.00 robot'), isNull);

      state.sendMessage(placeId: 'shop', text: '   ', asBusiness: false);
      expect(state.thread('shop'), isEmpty);

      await state.signIn(method: 'google', handle: 'ada@leca.app');
      state.sendMessage(
        placeId: 'shop',
        text: 'hello   there',
        asBusiness: false,
      );
      expect(state.thread('shop').single.who, state.who);
      expect(state.thread('shop').single.text, 'hello there');
      expect(state.who, isNot(contains('ada@')));

      state.sendMessage(placeId: 'shop', text: 'open', asBusiness: true);
      expect(state.thread('shop').last.who, isEmpty);
      expect(state.thread('shop').last.name, 'Shop');
      expect(state.talkOk('shop'), isTrue);

      final forged = TalkLine(
        seq: 3,
        room: 'shop',
        kind: 'text',
        name: 'Ada',
        at: talkStamp(at),
        text: 'forged',
        prev: state.thread('shop').last.proof,
        proof: '00',
      );
      state.appendTalk(forged);
      expect(state.thread('shop'), hasLength(2));

      final extra = talkAppend(
        prior: [
          for (final message in state.thread('shop'))
            TalkLine(
              seq: message.seq,
              room: 'shop',
              kind: message.kind,
              name: message.name,
              who: message.who,
              at: message.stamp,
              text: message.text,
              prev: message.prev,
              proof: message.proof,
            ),
        ],
        room: 'shop',
        kind: 'text',
        name: 'Cy',
        at: at,
        text: 'joined',
      );
      state
        ..appendTalk(extra)
        ..appendTalk(extra);
      expect(state.thread('shop'), hasLength(3));
      expect(state.talkOk('shop'), isTrue);
    });
  });

  test('a saved desk comes back, and a damaged one does not crash', () async {
    final vault = MemoryVault();
    final first = LecaState(vault: vault);
    try {
      await first.signIn(method: 'google', handle: 'ada@leca.app');
      final key = await first.ensureDeviceKey();
      first
        ..toggleLocale()
        ..setRail('visa')
        ..setRadius(4)
        ..setBooking(
          const Booking(
            kind: BookKind.goods,
            title: 'Bicycle',
            amountUsd: 80,
            vehicleId: 'bicycle',
            card: 'leca-kh-1',
          ),
        )
        ..fileConsumerReport('b_9', '  late  ')
        ..fileConsumerReport('  ', 'ignored')
        ..suspendedPartnerIds.add('p_moto');
      first.businesses.add(
        const BusinessListing(
          id: 'b_9',
          kind: 'pharmacy',
          name: 'Tiny',
          cityId: 'kep',
        ),
      );
      await first.save();

      final second = LecaState(vault: vault);
      try {
        await second.restore();
        expect(second.session?.id, first.session?.id);
        expect(second.locale.languageCode, 'en');
        expect(second.railId, 'visa');
        expect(second.radiusKm, 4);
        expect(second.booking?.kind, BookKind.goods);
        expect(second.booking?.amountUsd, 80);
        expect(second.reports.single.note, 'late');
        expect(second.reports.single.kind, 'consumer');
        expect(second.suspendedPartnerIds, contains('p_moto'));
        expect(second.businesses.single.kind, 'pharmacy');
        expect((await second.ensureDeviceKey()).accountId, key.accountId);

        second.signOut();
        expect(second.signedIn, isFalse);
        expect(second.booking, isNull);
        expect(second.businesses, isEmpty);
        expect(second.reports, isEmpty);
      } finally {
        second.dispose();
      }
    } finally {
      first.dispose();
    }

    final damaged = LecaState(
      vault: MemoryVault(
        jsonEncode({
          'locale': 'fr',
          'cityId': 'atlantis',
          'railId': 'nope',
          'radiusKm': 0.2,
          'qty': {'nbc_khmer': 0, 'ghost': -1, 'amok': 2},
          'keySeed': '!!!!',
          'session': {'method': 'google'},
          'booking': {'kind': 'teleport', 'amountUsd': 1},
        }),
      ),
    );
    try {
      await damaged.restore();
      expect(damaged.restored, isTrue);
      expect(damaged.locale.languageCode, 'km');
      expect(damaged.cityId, 'phnom_penh');
      expect(damaged.railId, 'aba');
      expect(damaged.radiusKm, 1);
      expect(damaged.countOf('amok'), 2);
      expect(damaged.countOf('nbc_khmer'), 0);
      expect(damaged.session, isNull);
      expect(damaged.booking, isNull);
      expect(damaged.subtotalUsd, 8.5);
    } finally {
      damaged.dispose();
    }
  });
}
