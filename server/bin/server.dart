import 'dart:convert';
import 'dart:io';

import 'package:chow_auth/chow_auth.dart';
import 'package:chow_auth/quote.dart';
import 'package:chow_auth/talk_hub.dart';
import 'package:chow_auth/trust.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  // A price change is a new card file and a restart. Old proofs still
  // name the card they were made under.
  final cardPath = Platform.environment['CHOW_RATE_CARD'] ?? '';
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
        Platform.environment['CHOW_AUTH_DB'] ??
        '/var/lib/chow-auth/accounts.json',
  );
  final talk = TalkHub(
    logDir: Platform.environment['CHOW_TALK_DIR'] ?? '/var/lib/chow-auth/rooms',
    resolve: (token) {
      final user = core.userForToken(token);
      if (user == null) return null;
      return (id: user.id, name: user.displayName);
    },
  );
  final trust = TrustStore(
    path:
        Platform.environment['CHOW_TRUST_DB'] ??
        '/var/lib/chow-auth/trust.json',
    adminKey: Platform.environment['CHOW_ADMIN_KEY'] ?? '',
  );
  if (!trust.adminReady) {
    stdout.writeln('CHOW_ADMIN_KEY is unset: review endpoints are closed');
  }
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Leca on http://${server.address.host}:$port');
  await for (final request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request) &&
        request.uri.path == '/v1/room') {
      talk.attach(await WebSocketTransformer.upgrade(request));
      continue;
    }
    await handleAuth(core, request, trust: trust);
  }
}
