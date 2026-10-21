import 'auth.dart';
import 'auth_api.dart';
import 'state.dart';

/// One paid checkout, in cents, ready for the Nunchi coin ledger.
Map<String, Object?> ledgerLineFor(LecaState state, String orderId) {
  final booking = state.booking;
  final cents = (state.saleUsd * 100).round();
  final feeCents = (state.feeUsd * 100).round();
  final tipCents = state.acceptsTip ? (state.tipUsd * 100).round() : 0;
  final who = state.session?.id ?? state.guestId;
  final to = (booking?.title ?? state.payableLabel).trim();
  return {
    'id': orderId,
    'kind': booking?.kind.name ?? 'cart',
    'from': who,
    'to': to.isEmpty ? 'leca' : to,
    'cents': cents,
    'feeCents': feeCents,
    'tipCents': tipCents,
    'memo': booking?.detail ?? '',
  };
}

/// Posts the payment to the auth server, which applies it on the
/// nunchi-coins ledger. A missing server, or a guest, leaves the
/// checkout on this device. The server records the signed-in account
/// as the payer.
Future<String?> postLedger(
  Map<String, Object?> line, {
  required String token,
}) async {
  if (!AuthConfig.apiLive || token.isEmpty) return null;
  final posted = await AuthApi.post('/v1/ledger', line, token: token);
  final root = posted['root'];
  if (posted['ok'] != true || root == null || '$root'.isEmpty) {
    throw AuthApiException('ledger_failed');
  }
  return '$root';
}
