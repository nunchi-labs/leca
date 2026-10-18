import 'package:flutter_test/flutter_test.dart';
import 'package:leca/khqr.dart';
import 'package:leca/market.dart';

void main() {
  test('KHQR CRC-16/CCITT-FALSE matches a known vector', () {
    const body =
        '00020101021229160012leca.kh@abaa52045812530384054041.005802KH5904LECA6010Phnom Penh6304';
    expect(Khqr.crc16(body), 'D691');
  });

  test('dynamic KHQR verifies and carries ABA Bakong fields', () {
    final aba = MarketConfig.current.railById('aba');
    final qr = Khqr.generate(
      bakongAccountId: aba.bakongAccountId!,
      merchantName: MarketConfig.current.merchantName,
      merchantCity: 'Phnom Penh',
      amount: 3.15,
      currencyNumeric: 840,
      countryCode: 'KH',
      acquiringBank: aba.acquiringBank,
      billNumber: 'LECA09211200',
      storeLabel: 'Morning Nom Banh Chok',
      purpose: 'no soy',
      now: DateTime.utc(2026, 9, 21, 12),
    );
    expect(Khqr.verify(qr), isTrue);
    expect(qr.contains('leca.kh@abaa'), isTrue);
    expect(qr.contains('5802KH'), isTrue);
  });

  test('QrFactory supports KHQR banks, cash, and Stripe cards', () {
    final aba = QrFactory.build(
      rail: MarketConfig.current.railById('aba'),
      amountUsd: 2.5,
      orderId: 'LECA1',
      note: 'extra chilli',
      storeLabel: 'Kitchen',
      merchantCity: 'Siem Reap',
    );
    expect(Khqr.verify(aba.text), isTrue);

    final acleda = QrFactory.build(
      rail: MarketConfig.current.railById('acleda'),
      amountUsd: 2.5,
      orderId: 'LECA1',
      note: '',
      storeLabel: 'Kitchen',
      merchantCity: 'Siem Reap',
    );
    expect(Khqr.verify(acleda.text), isTrue);
    expect(acleda.text, contains('leca.kh@aclb'));

    final cash = QrFactory.build(
      rail: MarketConfig.current.railById('cash'),
      amountUsd: 2.5,
      orderId: 'LECA1',
      note: '',
      storeLabel: 'Kitchen',
      merchantCity: 'Siem Reap',
    );
    expect(cash.text, startsWith('CASH|KH|'));

    expect(
      () => QrFactory.build(
        rail: MarketConfig.cambodia.railById('visa'),
        amountUsd: 2.5,
        orderId: 'LECA1',
        note: '',
        storeLabel: 'Kitchen',
        merchantCity: 'Phnom Penh',
      ),
      throwsA(predicate<QrException>((e) => e.code == 'stripe_unconfigured')),
    );
    expect(
      () => QrFactory.build(
        rail: MarketConfig.cambodia.railById('discover'),
        amountUsd: 2.5,
        orderId: 'LECA1',
        note: '',
        storeLabel: 'Kitchen',
        merchantCity: 'Phnom Penh',
      ),
      throwsA(predicate<QrException>((e) => e.code == 'stripe_unconfigured')),
    );
  });
}
