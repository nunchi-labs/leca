import 'package:flutter_test/flutter_test.dart';
import 'package:leca/catalog.dart';
import 'package:leca/quote.dart';
import 'package:leca/records.dart';
import 'package:leca/state.dart';
import 'package:leca/talk.dart';
import 'package:leca/vault.dart';

void main() {
  test('a delivery fare is the rate card and the proof matches it', () {
    expect(
      fareCents(kind: 'delivery', vehicle: '', meters: 2000, minutes: 10),
      96,
    );
    expect(
      fareCents(kind: 'ride', vehicle: 'motorcycle', meters: 2000, minutes: 10),
      124,
    );
    expect(
      fareCents(kind: 'ride', vehicle: 'bicycle', meters: 2000, minutes: 10),
      87,
    );
    final quote = priceTrip(
      kind: 'delivery',
      fromLat: 11.5454,
      fromLng: 104.9108,
      toLat: 11.5564,
      toLng: 104.9282,
    );
    expect(quote.checksOut, isTrue);
    expect(quote.cents, greaterThanOrEqualTo(50));
    expect(quote.proof, hasLength(64));
  });

  test('chat, voice, and video form one proof, and a changed line fails', () {
    final state = LecaState();
    final at = DateTime.utc(2026, 10, 14, 3);
    state
      ..sendMessage(
        placeId: 'shop',
        text: 'hello',
        asBusiness: false,
        at: at,
        name: 'Ada',
      )
      ..sendMessage(
        placeId: 'shop',
        text: 'open',
        asBusiness: false,
        at: at,
        kind: 'voice',
        name: 'Bo',
      )
      ..sendMessage(
        placeId: 'shop',
        text: 'open',
        asBusiness: false,
        at: at,
        kind: 'video',
        name: 'Ada',
      );
    expect(state.talkOk('shop'), isTrue);
    expect(state.thread('shop').map((m) => m.kind), ['text', 'voice', 'video']);
    final first = state.messages.first;
    state.messages[0] = ChatMessage(
      id: first.id,
      placeId: first.placeId,
      text: 'changed',
      asBusiness: first.asBusiness,
      at: first.at,
      kind: first.kind,
      name: first.name,
      seq: first.seq,
      prev: first.prev,
      proof: first.proof,
      stamp: first.stamp,
    );
    expect(state.talkOk('shop'), isFalse);
  });

  test(
    'a proposed price waits for allow, and the automatic fare still proves',
    () {
      final state = LecaState();
      final kitchen = Catalog.kitchens.first;
      state.addDish(kitchen.menu.first, kitchen);
      final automatic = state.deliveryQuoteOf(kitchen);
      expect(automatic.checksOut, isTrue);
      expect(state.deliveryUsd, automatic.usd);
      final before = state.totalUsd;
      state.proposeFare(
        state.deliveryFareKey(kitchen),
        automatic.usd,
        automatic.usd + 0.5,
      );
      expect(state.deliveryUsd, automatic.usd);
      expect(state.totalUsd, before);
      state.allowFare(state.deliveryFareKey(kitchen));
      expect(state.deliveryUsd, closeTo(automatic.usd + 0.5, 0.001));
      expect(state.totalUsd, greaterThan(before));
      expect(state.deliveryQuoteOf(kitchen).proof, automatic.proof);

      // A second bargain elsewhere leaves the first one untouched.
      state.proposeFare('ride:tuktuk', 1.80, 2.40);
      expect(state.payable('ride:tuktuk', 1.80), 1.80);
      expect(state.deliveryUsd, closeTo(automatic.usd + 0.5, 0.001));
      state.allowFare('ride:tuktuk');
      expect(state.payable('ride:tuktuk', 1.80), 2.40);
      expect(state.deliveryUsd, closeTo(automatic.usd + 0.5, 0.001));
    },
  );

  test('a rental is priced place to place, with or without a driver', () {
    final withDriver = priceTrip(
      kind: 'rent',
      vehicle: 'car',
      fromLat: 11.5454,
      fromLng: 104.9108,
      toLat: 13.3633,
      toLng: 103.8564,
    );
    final selfDrive = priceTrip(
      kind: 'rent-self',
      vehicle: 'car',
      fromLat: 11.5454,
      fromLng: 104.9108,
      toLat: 13.3633,
      toLng: 103.8564,
    );
    expect(withDriver.checksOut, isTrue);
    expect(selfDrive.checksOut, isTrue);
    expect(withDriver.meters, selfDrive.meters);
    expect(withDriver.cents, greaterThan(selfDrive.cents));
    expect(withDriver.proof, isNot(selfDrive.proof));
    final loop = priceTrip(
      kind: 'rent-self',
      vehicle: 'car',
      fromLat: 13.3633,
      fromLng: 103.8564,
      toLat: 13.3633,
      toLng: 103.8564,
      hours: 24,
    );
    final hop = priceTrip(
      kind: 'rent-self',
      vehicle: 'car',
      fromLat: 13.3633,
      fromLng: 103.8564,
      toLat: 13.3633,
      toLng: 103.8564,
    );
    expect(loop.checksOut, isTrue);
    expect(loop.hours, 24);
    expect(loop.cents, greaterThan(hop.cents));
    final along = priceTrip(
      kind: 'ride',
      vehicle: 'car',
      fromLat: 11.5454,
      fromLng: 104.9108,
      toLat: 13.3633,
      toLng: 103.8564,
      routeMeters: 320000,
      traffic: 300,
    );
    expect(along.routed, isTrue);
    expect(along.meters, 320000);
    expect(along.minutes, 300);
    expect(along.checksOut, isTrue);
    final builtIn = RateCard.active;
    RateCard.adopt(
      RateCard(
        id: 'leca-kh-test',
        kinds: builtIn.kinds,
        scales: builtIn.scales,
        minCents: 99,
      ),
    );
    try {
      expect(along.card, 'leca-kh-1');
      expect(along.checksOut, isTrue);
      expect(
        priceTrip(
          kind: 'delivery',
          fromLat: 11.5,
          fromLng: 104.9,
          toLat: 11.6,
          toLng: 104.9,
        ).card,
        'leca-kh-test',
      );
    } finally {
      RateCard.known.remove('leca-kh-test');
      RateCard.active = RateCard.builtIn;
    }
    expect(
      fareCents(kind: 'rent', vehicle: 'car', meters: 2000, minutes: 10),
      greaterThan(
        fareCents(
          kind: 'rent',
          vehicle: 'motorcycle',
          meters: 2000,
          minutes: 10,
        ),
      ),
    );
  });

  test('bargaining goes back and forth until one side ends it', () {
    final state = LecaState();
    const key = 'rent:car:driver:1000:5';
    state.proposeFare(key, 10, 8, proposer: 'customer');
    expect(state.askFor(key)?.pending?.side, 'customer');
    expect(state.payable(key, 10), 10);

    // The driver counters instead of allowing. Still the app price.
    state.proposeFare(key, 10, 12.5, proposer: 'driver');
    expect(state.askFor(key)?.pending?.side, 'driver');
    expect(state.askFor(key)?.bids.length, 2);
    expect(state.payable(key, 10), 10);

    // The customer counters again, the driver allows that one.
    state
      ..proposeFare(key, 10, 9, proposer: 'customer')
      ..allowFare(key);
    expect(state.payable(key, 10), 9);
    expect(state.askFor(key)?.open, isFalse);

    // Another ask after agreement keeps the agreed price until answered.
    state.proposeFare(key, 10, 11, proposer: 'driver');
    expect(state.payable(key, 10), 9);
    state.endFare(key);
    expect(state.askFor(key)?.ended, isTrue);
    expect(state.askFor(key)?.pending, isNull);
    expect(state.payable(key, 10), 9);

    // allow after end does nothing; a new bid reopens.
    state.allowFare(key);
    expect(state.payable(key, 10), 9);
    state.proposeFare(key, 10, 9.5, proposer: 'driver');
    expect(state.askFor(key)?.ended, isFalse);
    expect(state.askFor(key)?.bids.length, 5);

    expect(state.payable('rent:car:self:1000:5', 7), 7);
  });

  test('state survives a restart: chat chain, bargain, cart, driver', () async {
    final vault = MemoryVault();
    final first = LecaState(vault: vault);
    await first.restore();
    final kitchen = Catalog.kitchens.first;
    first.addDish(kitchen.menu.first, kitchen);
    final at = DateTime.utc(2026, 10, 14, 3);
    first
      ..sendMessage(placeId: kitchen.id, text: 'hi', asBusiness: false, at: at)
      ..sendMessage(
        placeId: kitchen.id,
        text: 'ask 2.40 driver',
        asBusiness: false,
        at: at,
        kind: 'price',
        name: 'Dara',
      );
    final key = first.deliveryFareKey(kitchen);
    first
      ..proposeFare(key, 2, 2.4, proposer: 'driver')
      ..allowFare(key)
      ..setRadius(25);
    await first.save();
    expect(vault.json, isNotNull);

    final second = LecaState(vault: vault);
    await second.restore();
    expect(second.restored, isTrue);
    expect(second.itemCount, 1);
    expect(second.cartKitchen?.id, kitchen.id);
    expect(second.thread(kitchen.id).length, 2);
    expect(second.talkOk(kitchen.id), isTrue);
    expect(second.thread(kitchen.id).last.kind, 'price');
    expect(second.payable(key, 2), 2.4);
    expect(second.askFor(key)?.bids.length, 1);
    expect(second.radiusKm, 25);
    expect(second.deliveryUsd, 2.4);

    final blank = LecaState(vault: MemoryVault('not json'));
    await blank.restore();
    expect(blank.restored, isTrue);
    expect(blank.itemCount, 0);
  });

  test('a price line is bound to an account handle, not a name', () {
    final a = talkAppend(
      prior: const [],
      room: 'r',
      kind: 'price',
      name: 'Sokha',
      who: talkWho('phone:85512000001'),
      at: DateTime.utc(2026, 10, 14, 3),
      text: 'ask 2.40 driver',
    );
    final b = talkAppend(
      prior: const [],
      room: 'r',
      kind: 'price',
      name: 'Sokha',
      who: talkWho('phone:85512000002'),
      at: DateTime.utc(2026, 10, 14, 3),
      text: 'ask 2.40 driver',
    );
    expect(a.proof, isNot(b.proof));
    expect(a.who, hasLength(16));
    expect(a.who, isNot(contains('85512')));
    expect(talkBody(a), contains('leca-talk/2'));
    expect(PriceLine.parse('end 0.00 customer')?.verb, 'end');
    expect(PriceLine.parse('ask 0.00 driver'), isNull);
    expect(PriceLine.parse('steal 2.00 driver'), isNull);
  });

  test('a price line sits in the same chain as the words', () {
    final state = LecaState();
    final at = DateTime.utc(2026, 10, 14, 3);
    state
      ..sendMessage(
        placeId: 'nom_banh_chok',
        text: 'can you do more?',
        asBusiness: false,
        at: at,
        name: 'Dara',
      )
      ..sendMessage(
        placeId: 'nom_banh_chok',
        text: 'ask 2.40 driver',
        asBusiness: false,
        at: at,
        kind: 'price',
        name: 'Dara',
      )
      ..sendMessage(
        placeId: 'nom_banh_chok',
        text: 'allow 2.40 customer',
        asBusiness: false,
        at: at,
        kind: 'price',
        name: 'Sokha',
      );
    expect(state.talkOk('nom_banh_chok'), isTrue);
    expect(state.thread('nom_banh_chok').map((m) => m.kind), [
      'text',
      'price',
      'price',
    ]);
  });

  test('the talk proof uses the published line, not a hidden id', () {
    final line = talkAppend(
      prior: const [],
      room: 'ride:tuktuk',
      kind: 'text',
      name: 'Ada',
      at: DateTime.utc(2026, 10, 14, 3),
      text: 'on my way',
    );
    expect(line.checksOut, isTrue);
    expect(talkBody(line), isNot(contains('endpoint')));
    expect(line.name, 'Ada');
  });
}
