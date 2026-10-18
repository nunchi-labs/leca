import 'market.dart';

class PayPayload {
  const PayPayload({required this.text, required this.rail});

  final String text;
  final PaymentRail rail;
}

class StripeCheckout {
  static const publishableKey = String.fromEnvironment('STRIPE_PK');

  static bool get hasPublishableKey => publishableKey.startsWith('pk_');

  /// A Checkout Session URL from the Leca server. A publishable key
  /// cannot create a charge, so a missing session is not a payment link.
  static String? checkoutUrl({String? sessionUrl}) {
    if (sessionUrl == null) return null;
    final uri = Uri.tryParse(sessionUrl);
    if (uri == null || uri.scheme != 'https') return null;
    if (uri.host != 'checkout.stripe.com') return null;
    return sessionUrl;
  }
}

class QrFactory {
  static PayPayload build({
    required PaymentRail rail,
    required double amountUsd,
    required String orderId,
    required String note,
    required String storeLabel,
    required String merchantCity,
    MarketConfig market = MarketConfig.current,
  }) {
    if (amountUsd <= 0) {
      throw const QrException.invalidAmount();
    }
    switch (rail.kind) {
      case RailKind.khqr:
        final account = rail.bakongAccountId;
        if (account == null || account.isEmpty) {
          throw const QrException.failed();
        }
        return PayPayload(
          rail: rail,
          text: Khqr.generate(
            bakongAccountId: account,
            merchantName: market.merchantName,
            merchantCity: merchantCity,
            amount: amountUsd,
            currencyNumeric: market.currencyNumeric,
            countryCode: market.countryCode,
            acquiringBank: rail.acquiringBank,
            billNumber: orderId,
            storeLabel: storeLabel,
            purpose: note,
          ),
        );
      case RailKind.stripe:
        final url = StripeCheckout.checkoutUrl();
        if (url == null) throw const QrException.stripe();
        return PayPayload(rail: rail, text: url);
      case RailKind.generic:
        return PayPayload(
          rail: rail,
          text:
              'LECA|${market.countryCode}|$orderId|USD${amountUsd.toStringAsFixed(2)}|$note',
        );
      case RailKind.cash:
        return PayPayload(
          rail: rail,
          text:
              'CASH|${market.countryCode}|$orderId|USD${amountUsd.toStringAsFixed(2)}',
        );
    }
  }
}

class QrException implements Exception {
  const QrException.invalidAmount() : code = 'invalid_amount';
  const QrException.failed() : code = 'failed';
  const QrException.stripe() : code = 'stripe_unconfigured';

  final String code;
}

/// EMVCo-style KHQR (Bakong) payload. Local generation — no bank API required.
class Khqr {
  static String tlv(String tag, String value) {
    var clipped = value;
    if (clipped.length > 99) clipped = clipped.substring(0, 99);
    final len = clipped.length.toString().padLeft(2, '0');
    return '$tag$len$clipped';
  }

  static String crc16(String data) {
    var crc = 0xFFFF;
    for (final unit in data.codeUnits) {
      crc ^= unit << 8;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
        crc &= 0xFFFF;
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  static bool verify(String payload) {
    const tail = 8;
    if (payload.length < tail) return false;
    final idx = payload.length - tail;
    if (payload.substring(idx, idx + 4) != '6304') return false;
    final body = payload.substring(0, idx + 4);
    final got = payload.substring(idx + 4);
    return crc16(body) == got;
  }

  static String generate({
    required String bakongAccountId,
    required String merchantName,
    required String merchantCity,
    required double amount,
    required int currencyNumeric,
    required String countryCode,
    String mcc = '5812',
    String? acquiringBank,
    String? billNumber,
    String? storeLabel,
    String? purpose,
    DateTime? now,
    Duration ttl = const Duration(minutes: 15),
  }) {
    final mai = StringBuffer()..write(tlv('00', bakongAccountId));
    if (acquiringBank != null && acquiringBank.isNotEmpty) {
      mai.write(tlv('02', acquiringBank));
    }

    final add = StringBuffer();
    if (billNumber != null && billNumber.isNotEmpty) {
      add.write(tlv('01', _cap(billNumber, 25)));
    }
    if (storeLabel != null && storeLabel.isNotEmpty) {
      add.write(tlv('03', _cap(_ascii(storeLabel), 25)));
    }
    final asciiPurpose = purpose == null ? '' : _ascii(purpose);
    if (asciiPurpose.isNotEmpty) {
      add.write(tlv('08', _cap(asciiPurpose, 25)));
    }

    final generatedAt = now ?? DateTime.now().toUtc();
    final expires = generatedAt.add(ttl);
    final timestamp = tlv(
      '99',
      tlv('00', generatedAt.millisecondsSinceEpoch.toString()) +
          tlv('01', expires.millisecondsSinceEpoch.toString()),
    );

    final body = StringBuffer()
      ..write(tlv('00', '01'))
      ..write(tlv('01', '12'))
      ..write(tlv('29', mai.toString()))
      ..write(tlv('52', mcc))
      ..write(tlv('53', currencyNumeric.toString().padLeft(3, '0')))
      ..write(tlv('54', _amount(amount, currencyNumeric)))
      ..write(tlv('58', countryCode))
      ..write(tlv('59', _cap(merchantName, 25)))
      ..write(tlv('60', _cap(merchantCity, 15)));
    if (add.isNotEmpty) {
      body.write(tlv('62', add.toString()));
    }
    body.write(timestamp);

    final withCrcTag = '${body}6304';
    return '$withCrcTag${crc16(withCrcTag)}';
  }

  static String _amount(double amount, int currencyNumeric) {
    if (currencyNumeric == 116) {
      return amount.round().toString();
    }
    final cents = (amount * 100).round();
    return (cents / 100).toStringAsFixed(2);
  }

  static String _cap(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  static String _ascii(String value) {
    final buf = StringBuffer();
    for (final unit in value.codeUnits) {
      if (unit >= 0x20 && unit <= 0x7E) {
        buf.writeCharCode(unit);
      }
    }
    return buf.toString().trim();
  }
}
