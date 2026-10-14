import 'dart:io';

import 'package:chow_auth/chow_auth.dart';
import 'package:chow_auth/talk_hub.dart';

Future<void> main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
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
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Leca on http://${server.address.host}:$port');
  await for (final request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request) &&
        request.uri.path == '/v1/room') {
      talk.attach(await WebSocketTransformer.upgrade(request));
      continue;
    }
    await handleAuth(core, request);
  }
}
