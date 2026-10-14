import 'package:chow/catalog.dart';
import 'package:chow/quote.dart';
import 'package:chow/records.dart';
import 'package:chow/state.dart';
import 'package:chow/talk.dart';
import 'package:flutter_test/flutter_test.dart';

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
    final state = ChowState();
    final at = DateTime.utc(2026, 10, 14, 3);
    state.sendMessage(
      placeId: 'shop',
      text: 'hello',
      asBusiness: false,
      at: at,
      name: 'Ada',
    );
    state.sendMessage(
      placeId: 'shop',
      text: 'open',
      asBusiness: false,
      at: at,
      kind: 'voice',
      name: 'Bo',
    );
    state.sendMessage(
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
      final state = ChowState();
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
      state.allowFare();
      expect(state.deliveryUsd, closeTo(automatic.usd + 0.5, 0.001));
      expect(state.totalUsd, greaterThan(before));
      expect(state.deliveryQuoteOf(kitchen).proof, automatic.proof);

      state.proposeFare('ride:tuktuk', 1.80, 2.40);
      expect(state.payable('ride:tuktuk', 1.80), 1.80);
      state.allowFare();
      expect(state.payable('ride:tuktuk', 1.80), 2.40);
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

  test('either side may propose, and the price moves only on allow', () {
    final state = ChowState();
    const key = 'rent:car:driver:1000:5';
    state.proposeFare(key, 10, 8, proposer: 'customer');
    expect(state.fareAsk?.proposer, 'customer');
    expect(state.payable(key, 10), 10);
    state.allowFare();
    expect(state.payable(key, 10), 8);

    state.proposeFare(key, 10, 12.5, proposer: 'driver');
    expect(state.fareAsk?.proposer, 'driver');
    expect(state.fareAsk?.allowed, isFalse);
    expect(state.payable(key, 10), 10);
    state.allowFare();
    expect(state.payable(key, 10), 12.5);
    expect(state.payable('rent:car:self:1000:5', 7), 7);
  });

  test('a price line sits in the same chain as the words', () {
    final state = ChowState();
    final at = DateTime.utc(2026, 10, 14, 3);
    state.sendMessage(
      placeId: 'nom_banh_chok',
      text: 'can you do more?',
      asBusiness: false,
      at: at,
      name: 'Dara',
    );
    state.sendMessage(
      placeId: 'nom_banh_chok',
      text: 'ask 2.40 driver',
      asBusiness: false,
      at: at,
      kind: 'price',
      name: 'Dara',
    );
    state.sendMessage(
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
