import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:leca_auth/leca_auth.dart';
import 'package:leca_auth/quote.dart';
import 'package:leca_auth/talk_hub.dart';
import 'package:leca_auth/trust.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  // A price change is a new card file and a restart. Old proofs still
  // name the card they were made under.
  final cardPath = Platform.environment['LECA_RATE_CARD'] ?? '';
  if (cardPath.isNotEmpty && File(cardPath).existsSync()) {
    final card = RateCard.fromJson(
      jsonDecode(File(cardPath).readAsStringSync()),
    );
    if (card != null) RateCard.adopt(card);
  }
  stdout.writeln('Rate card ${RateCard.active.id}');
  final core = AuthCore(
    config: AuthConfig.fromEnvironment(),
    accountPath:
        Platform.environment['LECA_AUTH_DB'] ??
        '/var/lib/leca-auth/accounts.json',
  );
  final talk = TalkHub(
    logDir: Platform.environment['LECA_TALK_DIR'] ?? '/var/lib/leca-auth/rooms',
    resolve: (token) {
      final user = core.userForToken(token);
      if (user == null) return null;
      return (id: user.id, name: user.displayName);
    },
  );
  final trust = TrustStore(
    path:
        Platform.environment['LECA_TRUST_DB'] ??
        '/var/lib/leca-auth/trust.json',
    adminKey: Platform.environment['LECA_ADMIN_KEY'] ?? '',
  );
  if (!trust.adminReady) {
    stdout.writeln('LECA_ADMIN_KEY is unset: review endpoints are closed');
  }
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Leca on http://${server.address.host}:$port');
  await for (final request in server) {
    unawaited(_serve(request, core, talk, trust));
  }
}

Future<void> _serve(
  HttpRequest request,
  AuthCore core,
  TalkHub talk,
  TrustStore trust,
) async {
  try {
    if (WebSocketTransformer.isUpgradeRequest(request) &&
        request.uri.path == '/v1/room') {
      talk.attach(await WebSocketTransformer.upgrade(request));
      return;
    }
    await handleAuth(core, request, trust: trust);
  } on Object catch (error) {
    stderr.writeln('request failed: $error');
    try {
      request.response.statusCode = 500;
      await request.response.close();
    } on Object catch (_) {}
  }
}
