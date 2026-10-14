import 'dart:convert';
import 'dart:typed_data';

import 'package:chow/identity.dart';
import 'package:chow/rate.dart';
import 'package:chow/state.dart';
import 'package:flutter_test/flutter_test.dart';

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'identity matches the name on the card and rejects a copied photo',
    () async {
      expect(
        await Identity.check(
          legalName: 'Sokha Meas',
          nameOnId: 'sokha  meas',
          idNumber: '123 456 789',
          selfie: _pngA,
          idCard: _pngB,
        ),
        isNull,
      );
      expect(
        await Identity.check(
          legalName: 'Sokha',
          nameOnId: 'Dara',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
        ),
        'name_mismatch',
      );
      expect(
        await Identity.check(
          legalName: 'Sokha',
          nameOnId: 'Sokha',
          idNumber: '12',
          selfie: _pngA,
          idCard: _pngB,
        ),
        'id_invalid',
      );
      expect(
        await Identity.check(
          legalName: 'Sokha',
          nameOnId: 'Sokha',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngA,
        ),
        'photo_same',
      );
      expect(
        await Identity.check(
          legalName: 'Sokha',
          nameOnId: 'Sokha',
          idNumber: '123456',
          selfie: Uint8List.fromList([1, 2, 3, 4]),
          idCard: Uint8List.fromList([5, 6, 7, 8]),
        ),
        'photo_invalid',
      );
    },
  );

  test('reply color uses working hours only', () {
    final morning = DateTime(2026, 10, 7, 9);
    final night = DateTime(2026, 10, 7, 23);
    expect(isWorkingHour(morning), isTrue);
    expect(isWorkingHour(night), isFalse);
    expect(repliesFast(120), isTrue);
    expect(repliesFast(301), isFalse);
    expect(
      inHoursDelay(
        asked: morning,
        replied: morning.add(const Duration(minutes: 2)),
      ),
      120,
    );
    expect(
      inHoursDelay(
        asked: night,
        replied: night.add(const Duration(minutes: 1)),
      ),
      isNull,
    );
  });

  test(
    'driver signup, shop item, chat rate, and rider fare permission',
    () async {
      final state = ChowState();
      expect(
        await state.registerDriver(
          legalName: 'Sokha',
          nameOnId: 'Sokha',
          idNumber: '123456',
          phone: '012345678',
          vehicleKind: '',
          selfie: _pngA,
          idCard: _pngB,
        ),
        'vehicle_invalid',
      );
      expect(state.setDriving(value: true), 'online_blocked');
      expect(
        await state.registerDriver(
          legalName: 'Sokha Meas',
          nameOnId: 'Sokha Meas',
          idNumber: '123456789',
          phone: '012345678',
          vehicleKind: 'tuktuk',
          selfie: _pngA,
          idCard: _pngB,
          licenceNumber: 'PP12345',
          plate: '1A-8830',
          registration: 'REG-1001',
          inspection: 'INS-1001',
          insurance: 'POL-1001',
          logoOnVehicle: true,
          independentPartner: true,
          trainedTrafficLaw: true,
          trainedDriving: true,
          trainedService: true,
          trainedConduct: true,
        ),
        isNull,
      );
      expect(state.driver?.vehicleKind, 'tuktuk');
      expect(state.driver?.staffId, 'LECA-KH-456789');
      expect(state.setDriving(value: true), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(
        state.openJobs.map((job) => job.kind),
        containsAll(['food', 'ride', 'send']),
      );
      state.acceptJob('j_food');
      expect(state.acceptedJobs.single.kind, 'food');
      expect(state.openJobs.map((job) => job.id), isNot(contains('j_food')));

      await state.openBusiness(kind: 'baby', name: 'Tiny');
      expect(state.supplyError, 'seller_kyc');
      await state.openBusiness(
        kind: 'baby',
        name: 'Tiny',
        sellerName: 'Sokha Meas',
        sellerPhone: '012345678',
        sellerId: '123456789',
      );
      final id = state.businesses.single.id;
      expect(
        state.addItem(businessId: id, description: '', usd: 2, photo: _pngA),
        'item_invalid',
      );
      expect(
        state.addItem(
          businessId: id,
          description: 'cotton blanket',
          usd: 4.5,
          photo: _pngA,
        ),
        'item_khmer',
      );
      expect(
        state.addItem(
          businessId: id,
          description: 'ភួយកប្បាស',
          usd: 4.5,
          photo: _pngA,
        ),
        isNull,
      );
      expect(state.itemsFor(id).single.description, 'ភួយកប្បាស');

      final asked = DateTime(2026, 10, 7, 10);
      state.sendMessage(
        placeId: id,
        text: 'Is this in stock?',
        asBusiness: false,
        at: asked,
      );
      state.sendMessage(
        placeId: id,
        text: 'Yes',
        asBusiness: true,
        at: asked.add(const Duration(minutes: 4)),
      );
      expect(state.replySecondsFor(id)! <= 300, isTrue);
      expect(repliesFast(state.replySecondsFor(id)!), isTrue);

      final late = DateTime(2026, 10, 7, 22);
      state.sendMessage(
        placeId: id,
        text: 'Tonight?',
        asBusiness: false,
        at: late,
      );
      state.sendMessage(
        placeId: id,
        text: 'Tomorrow',
        asBusiness: true,
        at: late.add(const Duration(hours: 1)),
      );
      expect(state.replySecondsFor(id), 240);

      state.proposeFare('ride:tuktuk', 1.80, 2.40);
      expect(state.payable('ride:tuktuk', 1.80), 1.80);
      state.allowFare();
      expect(state.payable('ride:tuktuk', 1.80), 2.40);

      expect(state.replySecondsFor('pork_rice'), 900);
      expect(repliesFast(state.replySecondsFor('nom_banh_chok')!), isTrue);
    },
  );
}
