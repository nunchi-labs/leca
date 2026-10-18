import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/auth.dart';
import 'package:leca/compliance.dart';
import 'package:leca/device_key.dart';
import 'package:leca/identity.dart';
import 'package:leca/khqr.dart';
import 'package:leca/market.dart';
import 'package:leca/rate.dart';
import 'package:leca/records.dart';
import 'package:leca/state.dart';

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

const _abroad = MarketConfig(
  countryCode: 'SG',
  defaultLocale: Locale('en'),
  cities: [
    City(
      id: 'sg',
      nameKm: 'សិង្ហបុរី',
      nameEn: 'Singapore',
      latitude: 1.3,
      longitude: 103.8,
    ),
  ],
  defaultCityId: 'sg',
  currencyCode: 'SGD',
  currencyNumeric: 702,
  usdToLocal: 1.3,
  merchantName: 'LECA',
  defaultRailId: 'cash',
  rails: [
    PaymentRail(
      id: 'cash',
      nameKm: 'Cash',
      nameEn: 'Cash',
      kind: RailKind.cash,
    ),
  ],
  exampleVehicles: [],
);

DriverProfile _driver({
  String kind = 'bicycle',
  String review = 'local',
  bool trained = true,
  Uint8List? licencePhoto,
}) {
  return DriverProfile(
    legalName: 'Ada',
    nameOnId: 'Ada',
    idNumber: '123456789',
    phone: '012345678',
    vehicleKind: kind,
    selfie: _pngA,
    idCard: _pngB,
    licenceNumber: 'PP12345',
    plate: '2A-1001',
    registration: 'REG-1001',
    insurance: 'POL-1001',
    logoOnVehicle: true,
    independentPartner: true,
    trained: trained,
    staffId: 'LECA-KH-456789',
    licencePhoto: licencePhoto,
    registrationPhoto: licencePhoto,
    insurancePhoto: licencePhoto,
    review: review,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'KHQR clips text, prices riel as a whole number, and rejects a bad crc',
    () {
      final riel = Khqr.generate(
        bakongAccountId: 'leca.kh@abaa',
        merchantName: 'A' * 30,
        merchantCity: 'Phnom Penh extra',
        amount: 4100.4,
        currencyNumeric: 116,
        countryCode: 'KH',
        purpose: 'no soy បាយ',
        storeLabel: 'Kitchen',
        now: DateTime.utc(2026, 10, 18, 12),
      );
      expect(Khqr.verify(riel), isTrue);
      expect(riel.contains('A' * 25), isTrue);
      expect(riel.contains('A' * 26), isFalse);
      expect(riel.contains('54044100'), isTrue);
      expect(riel.contains('បាយ'), isFalse);
      expect(riel.contains('no soy'), isTrue);
      expect(riel.contains('Phnom Penh extra'), isFalse);
      expect(riel.contains('Phnom Penh extr'), isTrue);

      final broken = '${riel.substring(0, 20)}X${riel.substring(21)}';
      expect(Khqr.verify(broken), isFalse);
      expect(Khqr.verify('6304abcd'), isFalse);
      expect(Khqr.verify('short'), isFalse);
      expect(Khqr.verify(riel.toLowerCase()), isFalse);

      expect(Khqr.tlv('54', 'A' * 120).length, 2 + 2 + 99);

      expect(
        () => QrFactory.build(
          rail: MarketConfig.cambodia.railById('cash'),
          amountUsd: 0,
          orderId: 'LECA1',
          note: '',
          storeLabel: 'Kitchen',
          merchantCity: 'Kep',
        ),
        throwsA(predicate<QrException>((e) => e.code == 'invalid_amount')),
      );

      final cash = QrFactory.build(
        rail: MarketConfig.cambodia.railById('cash'),
        amountUsd: 1.5,
        orderId: 'LECA1',
        note: 'tip',
        storeLabel: 'Kitchen',
        merchantCity: 'Kep',
      );
      expect(cash.text, 'CASH|KH|LECA1|USD1.50');

      const generic = PaymentRail(
        id: 'other',
        nameKm: 'ផ្សេង',
        nameEn: 'Other',
        kind: RailKind.generic,
      );
      final other = QrFactory.build(
        rail: generic,
        amountUsd: 1.5,
        orderId: 'LECA1',
        note: 'tip',
        storeLabel: 'Kitchen',
        merchantCity: 'Kep',
      );
      expect(other.text, 'LECA|KH|LECA1|USD1.50|tip');

      expect(StripeCheckout.hasPublishableKey, isFalse);
      expect(StripeCheckout.checkoutUrl(), isNull);
      expect(
        () => QrFactory.build(
          rail: const PaymentRail(
            id: 'visa',
            nameKm: 'វីសា',
            nameEn: 'Visa',
            kind: RailKind.stripe,
          ),
          amountUsd: 2.5,
          orderId: 'LECA 1',
          note: '',
          storeLabel: 'Leca',
          merchantCity: 'Phnom Penh',
        ),
        throwsA(predicate<QrException>((e) => e.code == 'stripe_unconfigured')),
      );
    },
  );

  test(
    'identity wants two different photos, a matching name, and six digits',
    () async {
      expect(Identity.norm('  Sokha   Meas '), 'sokha meas');
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Ada',
          idNumber: '12345',
          selfie: _pngA,
          idCard: _pngB,
        ),
        'id_invalid',
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Bo',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
        ),
        'name_mismatch',
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Bo',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
          requireName: false,
        ),
        isNull,
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Ada',
          idNumber: '123456',
          selfie: Uint8List(0),
          idCard: _pngB,
        ),
        'photo_missing',
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Ada',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngA,
        ),
        'photo_same',
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Ada',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
          extras: <Uint8List?>[
            Uint8List.fromList([1, 2, 3, 4]),
          ],
        ),
        'photo_invalid',
      );
      expect(
        await Identity.check(
          legalName: 'Ada',
          nameOnId: 'Ada',
          idNumber: '123456',
          selfie: _pngA,
          idCard: _pngB,
          extras: <Uint8List?>[null],
        ),
        'photo_missing',
      );
    },
  );

  test('Cambodia papers, sellers, and partners follow the exemptions', () {
    expect(CambodiaRules.normKind('Tuk Tuk'), 'tuktuk');
    expect(CambodiaRules.isBicycle('bike'), isTrue);
    expect(CambodiaRules.isMotorcycle('Moto'), isTrue);
    expect(CambodiaRules.isTricycle('tuk'), isTrue);
    expect(CambodiaRules.isMotorcycleWithTrailer('motorcycle trailer'), isTrue);
    expect(CambodiaRules.needsInspection('moto'), isFalse);
    expect(CambodiaRules.needsInspection('tuk'), isTrue);
    expect(CambodiaRules.needsDomesticCert('tuk'), isFalse);
    expect(CambodiaRules.needsDomesticCert('motorcycle trailer'), isFalse);
    expect(CambodiaRules.needsMotorFile('bike'), isFalse);
    expect(CambodiaRules.staffIdFor('12'), 'LECA-KH-0012');
    expect(CambodiaRules.staffIdFor('ID 123456789'), 'LECA-KH-456789');
    expect(CambodiaRules.refOk('abc'), isFalse);
    expect(CambodiaRules.refOk(' abcd '), isTrue);

    expect(
      CambodiaRules.checkPartner(
        vehicleKind: 'car',
        licenceNumber: 'PP12345',
        plate: '2A-1001',
        registration: 'REG-1',
        inspection: 'INS-1',
        domesticCert: 'DOM-1',
        insurance: 'POL-1',
        logoOnVehicle: true,
        independentPartner: false,
        trainedTrafficLaw: true,
        trainedDriving: true,
        trainedService: true,
        trainedConduct: true,
      ),
      'partner_required',
    );
    expect(
      CambodiaRules.checkPartner(
        vehicleKind: 'car',
        licenceNumber: 'PP1',
        plate: '2A-1001',
        registration: 'REG-1',
        inspection: 'INS-1',
        domesticCert: 'DOM-1',
        insurance: 'POL-1',
        logoOnVehicle: true,
        independentPartner: true,
        trainedTrafficLaw: false,
        trainedDriving: true,
        trainedService: true,
        trainedConduct: true,
      ),
      'training_required',
    );
    expect(
      CambodiaRules.checkPartner(
        vehicleKind: 'car',
        licenceNumber: 'PP1',
        plate: '2A-1001',
        registration: 'REG-1',
        inspection: 'INS-1',
        domesticCert: 'DOM-1',
        insurance: 'POL-1',
        logoOnVehicle: false,
        independentPartner: true,
        trainedTrafficLaw: true,
        trainedDriving: true,
        trainedService: true,
        trainedConduct: true,
      ),
      'licence_invalid',
    );
    expect(
      CambodiaRules.checkPartner(
        vehicleKind: 'car',
        licenceNumber: 'PP12345',
        plate: '2A-1001',
        registration: 'REG-1',
        inspection: 'INS-1',
        domesticCert: 'DOM-1',
        insurance: 'POL-1',
        logoOnVehicle: false,
        independentPartner: true,
        trainedTrafficLaw: true,
        trainedDriving: true,
        trainedService: true,
        trainedConduct: true,
      ),
      'logo_required',
    );

    expect(CambodiaRules.documentsReady(_driver()), isTrue);
    expect(CambodiaRules.documentsReady(_driver(review: 'pending')), isFalse);
    expect(CambodiaRules.documentsReady(_driver(review: 'rejected')), isFalse);
    expect(CambodiaRules.documentsReady(_driver(trained: false)), isFalse);
    expect(CambodiaRules.documentsReady(_driver(kind: 'motorcycle')), isFalse);
    expect(
      CambodiaRules.documentsReady(
        _driver(kind: 'motorcycle', licencePhoto: _pngA),
      ),
      isTrue,
    );
    expect(
      CambodiaRules.onlineBlock(_driver(review: 'pending')),
      'online_blocked',
    );
    expect(CambodiaRules.onlineBlock(_driver()), isNull);

    expect(
      CambodiaRules.checkSeller(
        sellerName: '',
        sellerPhone: '012345678',
        sellerId: '123456',
      ),
      'seller_kyc',
    );
    expect(
      CambodiaRules.checkSeller(
        sellerName: 'Ada',
        sellerPhone: '0123',
        sellerId: '123456',
      ),
      'seller_kyc',
    );
    expect(
      CambodiaRules.checkSeller(
        sellerName: 'Ada',
        sellerPhone: '012345678',
        sellerId: '123456',
      ),
      isNull,
    );
    expect(CambodiaRules.checkItemText('cotton'), 'item_khmer');
    expect(CambodiaRules.checkItemText('ភួយ'), isNull);
    expect(CambodiaRules.containsKhmer('១'), isTrue);

    expect(CambodiaRules.applies(_abroad), isFalse);
    expect(CambodiaRules.requiresPersonalName(_abroad), isFalse);
    expect(
      CambodiaRules.rejectsPlatformFleet(autonomous: true, market: _abroad),
      isFalse,
    );
    expect(CambodiaRules.rejectsPlatformFleet(autonomous: true), isTrue);
    expect(
      CambodiaRules.checkPartner(
        market: _abroad,
        vehicleKind: 'car',
        licenceNumber: '',
        plate: '',
        registration: '',
        inspection: '',
        domesticCert: '',
        insurance: '',
        logoOnVehicle: false,
        independentPartner: false,
        trainedTrafficLaw: false,
        trainedDriving: false,
        trainedService: false,
        trainedConduct: false,
      ),
      isNull,
    );
    expect(
      CambodiaRules.checkSeller(
        market: _abroad,
        sellerName: '',
        sellerPhone: '',
        sellerId: '',
      ),
      isNull,
    );
    expect(CambodiaRules.checkItemText('cotton', _abroad), isNull);
    expect(CambodiaRules.onlineBlock(null, _abroad), isNull);

    final mine = CambodiaRules.match(
      vehicleKind: 'bicycle',
      suspended: {},
      driver: _driver(),
    );
    expect(mine?.id, 'LECA-KH-456789');
    expect(mine?.photo, isNotNull);

    final fallback = CambodiaRules.match(
      vehicleKind: 'motorcycle',
      suspended: {'p_moto', 'p_tuktuk', 'p_remorque', 'p_car', 'p_van'},
      driver: null,
    );
    expect(fallback?.id, 'p_bike');
    expect(
      CambodiaRules.match(
        vehicleKind: 'car',
        suspended: {for (final partner in samplePartners) partner.id},
        driver: null,
      ),
      isNull,
    );

    final shared = CambodiaRules.shareText(
      partner: null,
      cityName: 'Kep',
      at: DateTime.utc(2026, 10, 18, 1),
      audience: 'family',
    );
    expect(shared, contains('Driver: -'));
    expect(shared, contains('Location: unavailable'));
    expect(shared, contains('For: family'));
    expect(samplePartners.first.nameFor('km'), samplePartners.first.nameKm);
  });

  test('records round-trip, and a taken-down item leaves the shelf', () {
    final driver = _driver(kind: 'car', licencePhoto: _pngA);
    final again = DriverProfile.fromJson(driver.toJson());
    expect(again?.staffId, driver.staffId);
    expect(again?.licencePhoto, driver.licencePhoto);
    expect(again?.copyWith(suspended: true).suspended, isTrue);
    expect(DriverProfile.fromJson({'selfie': '!!!!'}), isNull);

    final item = ShopItem(
      id: 'item_1',
      businessId: 'b_1',
      description: 'ភួយ',
      usd: 4.5,
      photo: _pngA,
    );
    expect(ShopItem.fromJson(item.toJson())?.usd, 4.5);
    expect(item.takeDown().removed, isTrue);
    expect(ShopItem.fromJson({'id': 'x'}), isNull);
    expect(ShopItem.fromJson({'id': 'x', 'usd': 1, 'photo': '!!!!'}), isNull);

    final booking = Booking.fromJson({
      'kind': 'rent',
      'title': 'Car',
      'amountUsd': 12.5,
      'hours': 8,
      'meters': 1000,
    });
    expect(booking?.kind, BookKind.rent);
    expect(booking?.hours, 8);
    expect(Booking.fromJson(booking!.toJson())?.amountUsd, 12.5);
    expect(Booking.fromJson({'kind': 'teleport', 'amountUsd': 1}), isNull);

    final report = PlatformReport.fromJson({
      'id': 'r_1',
      'kind': 'safety',
      'category': 'violence',
      'subjectId': 'LECA-KH-1',
      'status': 'suspended',
    });
    expect(report?.copyWith(status: 'appealed', appeal: 'no').appeal, 'no');
    expect(PlatformReport.fromJson('nope'), isNull);

    final ask = FareAsk(
      key: 'ride:car',
      appUsd: 3,
    ).bid(2.5, 'customer').bid(3.5, 'driver');
    expect(ask.open, isTrue);
    expect(ask.allow().agreedUsd, 3.5);
    expect(ask.allow().pending, isNull);
    expect(ask.end().ended, isTrue);
    expect(ask.end().pending, isNull);
    expect(const FareAsk(key: 'x', appUsd: 1).allow().usd, 1);
    final stored = FareAsk.fromJson({
      'key': 'ride:car',
      'appUsd': 3,
      'bids': [
        {'usd': 2.5, 'side': 'customer'},
        'skip',
      ],
      'ended': true,
    });
    expect(stored?.bids, hasLength(1));
    expect(stored?.ended, isTrue);
    expect(FareAsk.fromJson({'key': 'x'}), isNull);
    expect(FareBid.fromJson({'usd': '2'}), isNull);

    final message = ChatMessage(
      id: 'm_1',
      placeId: 'shop',
      text: 'hi',
      asBusiness: false,
      at: DateTime.utc(2026, 10, 18, 1),
      who: 'abcd',
    );
    expect(ChatMessage.fromJson(message.toJson())?.who, 'abcd');
    expect(ChatMessage.fromJson({'at': 'nope'}), isNull);

    final session = Session.fromJson({
      'id': 'email:ada@leca.app',
      'method': 'email',
      'displayName': 'Ada',
      'handle': 'ada@leca.app',
    });
    expect(session?.toJson().containsKey('token'), isFalse);
    expect(Session.fromJson({'method': 'google'}), isNull);

    const business = BusinessListing(
      id: 'b_1',
      kind: 'pharmacy',
      name: 'Tiny',
      cityId: 'kep',
      openHour: 9,
    );
    expect(BusinessListing.fromJson(business.toJson())?.openHour, 9);
    expect(BusinessListing.fromJson({}), isNull);

    const vehicle = ListedVehicle(
      id: 'v_1',
      kind: 'boat',
      withDriver: true,
      autonomous: false,
      owner: true,
    );
    expect(ListedVehicle.fromJson(vehicle.toJson())?.owner, isTrue);
    expect(
      MarketConfig.cambodia.city('kep').nameFor(const Locale('en')),
      'Kep',
    );
    expect(
      MarketConfig.cambodia.railById('missing').id,
      MarketConfig.cambodia.rails.first.id,
    );
  });

  test(
    'a device key signs its proof, and the same seed is the same account',
    () async {
      expect(normalizeKeyName('  Ada\r\nBo  '), 'Ada  Bo');
      expect(normalizeKeyName('A' * 90).length, 80);
      expect(normalizeKeyName(''), isEmpty);

      final raw = Uint8List.fromList([0, 255, 16]);
      expect(decodeKey(encodeKey(raw)), raw);
      expect(
        keyHandle([0x0a, 0x0b, 0x0c, 0x0d, ...List<int>.filled(28, 0)]),
        '0a0b0c0d',
      );
      expect(
        keyProofMessage(challenge: 'c', publicKey: 'p', name: 'Ada'),
        'leca-key/1\nc\np\nAda\n',
      );

      final key = await DeviceKey.generate();
      final again = await DeviceKey.fromSeed(key.seed);
      expect(again.accountId, key.accountId);
      expect(again.publicKeyEncoded, key.publicKeyEncoded);
      expect(key.handle, hasLength(8));
      expect(key.accountId, startsWith('key:'));

      final proof = await key.signProof(challenge: 'abc', name: 'Ada');
      final public = SimplePublicKey(key.publicKey, type: KeyPairType.ed25519);
      final signed = utf8.encode(
        keyProofMessage(
          challenge: 'abc',
          publicKey: key.publicKeyEncoded,
          name: 'Ada',
        ),
      );
      expect(
        await Ed25519().verify(
          signed,
          signature: Signature(decodeKey(proof), publicKey: public),
        ),
        isTrue,
      );
      expect(
        await Ed25519().verify(
          utf8.encode(
            keyProofMessage(
              challenge: 'abc',
              publicKey: key.publicKeyEncoded,
              name: 'Bo',
            ),
          ),
          signature: Signature(decodeKey(proof), publicKey: public),
        ),
        isFalse,
      );
    },
  );

  test(
    'a complaint takes a listing down and leaves the chat average',
    () async {
      final state = LecaState();
      try {
        await state.openBusiness(
          kind: 'pharmacy',
          name: 'Tiny',
          sellerName: 'Ada',
          sellerPhone: '012345678',
          sellerId: '123456',
        );
        final id = state.businesses.single.id;
        expect(
          state.addItem(
            businessId: id,
            description: 'ភួយ',
            usd: 0,
            photo: _pngA,
          ),
          'item_invalid',
        );
        expect(
          state.addItem(
            businessId: id,
            description: 'ភួយ',
            usd: 4,
            photo: null,
          ),
          'item_invalid',
        );
        expect(
          state.addItem(
            businessId: id,
            description: 'ភួយ',
            usd: 4,
            photo: _pngA,
          ),
          isNull,
        );
        final itemId = state.itemsFor(id).single.id;
        state
          ..takeDownItem(itemId)
          ..takeDownItem(itemId)
          ..takeDownItem('missing');
        expect(state.itemsFor(id), isEmpty);
        expect(state.reports.map((report) => report.kind), ['takedown']);

        state.fileConsumerReport(id, 'torn');
        expect(state.reports.last.kind, 'consumer');
        expect(state.owns(id), isTrue);
        expect(state.hoursFor(id), (8, 21));
        expect(state.hoursFor('nom_banh_chok'), (8, 21));
        expect(state.hoursFor('missing'), (defaultOpenHour, defaultCloseHour));
        expect(state.replySecondsFor('missing'), isNull);
      } finally {
        state.dispose();
      }
    },
  );
}
