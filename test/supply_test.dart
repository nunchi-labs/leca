import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:leca/identity.dart';
import 'package:leca/rate.dart';
import 'package:leca/records.dart';
import 'package:leca/state.dart';

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
final _pngC = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
final _pngD = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPj/HwADBwIAMCbHYQAAAABJRU5ErkJggg==',
);
final _pngE = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
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
          legalName: '',
          nameOnId: '',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
          requireName: false,
        ),
        isNull,
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
      expect(
        await Identity.check(
          legalName: 'Sokha',
          nameOnId: 'Sokha',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
          extras: [_pngA],
        ),
        'photo_same',
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
      final state = LecaState();
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
          licencePhoto: _pngC,
          registrationPhoto: _pngD,
          insurancePhoto: _pngE,
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
      state
        ..sendMessage(
          placeId: id,
          text: 'Is this in stock?',
          asBusiness: false,
          at: asked,
        )
        ..sendMessage(
          placeId: id,
          text: 'Yes',
          asBusiness: true,
          at: asked.add(const Duration(minutes: 4)),
        );
      expect(state.replySecondsFor(id)! <= 300, isTrue);
      expect(repliesFast(state.replySecondsFor(id)!), isTrue);

      final late = DateTime(2026, 10, 7, 22);
      state
        ..sendMessage(
          placeId: id,
          text: 'Tonight?',
          asBusiness: false,
          at: late,
        )
        ..sendMessage(
          placeId: id,
          text: 'Tomorrow',
          asBusiness: true,
          at: late.add(const Duration(hours: 1)),
        );
      expect(state.replySecondsFor(id), 240);

      state.proposeFare('ride:tuktuk', 1.80, 2.40);
      expect(state.payable('ride:tuktuk', 1.80), 1.80);
      state.allowFare('ride:tuktuk');
      expect(state.payable('ride:tuktuk', 1.80), 2.40);

      expect(state.replySecondsFor('pork_rice'), 900);
      expect(repliesFast(state.replySecondsFor('nom_banh_chok')!), isTrue);
    },
  );

  test('item and report ids skip numbers that are already used', () {
    final state = LecaState();
    addTearDown(state.dispose);
    state.items.add(
      ShopItem(
        id: 'item_1',
        businessId: 'b',
        description: 'ភួយ',
        usd: 1,
        photo: _pngA,
      ),
    );
    state.items.add(
      ShopItem(
        id: 'item_2',
        businessId: 'b',
        description: 'កាហ្វេ',
        usd: 2,
        photo: _pngA,
      ),
    );
    state.items.removeAt(0);
    expect(
      state.addItem(
        businessId: 'b',
        description: 'ត្រី',
        usd: 1.236,
        photo: _pngA,
      ),
      isNull,
    );
    expect(state.items.last.id, 'item_1');
    expect(state.items.last.usd, 1.24);
    expect(state.items.map((item) => item.id).toSet(), hasLength(2));

    state.reports.add(
      const PlatformReport(
        id: 'r_2',
        kind: 'consumer',
        category: 'complaint',
        subjectId: 'b',
        status: 'recorded',
      ),
    );
    state.fileConsumerReport('b', 'ម្តងទៀត');
    expect(state.reports.last.id, 'r_1');
    expect(state.reports.map((report) => report.id).toSet(), hasLength(2));
  });
}
