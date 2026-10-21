import 'package:flutter_test/flutter_test.dart';
import 'package:leca/ledger.dart';
import 'package:leca/market.dart';
import 'package:leca/state.dart';

void main() {
  test('a paid checkout is one Nunchi ledger line, fee included', () {
    final state = LecaState()
      ..setBooking(
        const Booking(
          kind: BookKind.goods,
          title: 'Honda ADV 350',
          amountUsd: 4200,
          detail: 'sale · motorcycle',
        ),
      );
    final line = ledgerLineFor(state, 'order-1');
    expect(line['id'], 'order-1');
    expect(line['kind'], 'goods');
    expect(line['to'], 'Honda ADV 350');
    expect(line['cents'], 420000);
    expect(line['feeCents'], 21000);
    expect(line['tipCents'], 0);
    expect(line['memo'], 'sale · motorcycle');
    for (final usd in [0.09, 0.1, 1.25, 4.5, 19.99, 4200.0]) {
      final priced = LecaState()
        ..setBooking(
          Booking(
            kind: BookKind.goods,
            title: 'Item',
            amountUsd: usd,
            detail: 'x',
          ),
        );
      addTearDown(priced.dispose);
      final row = ledgerLineFor(priced, 'LECA1019211100ABCD');
      final cents = row['cents']! as int;
      expect(row['feeCents'], (cents * 5 / 100).round(), reason: '$usd');
    }
  });
}
