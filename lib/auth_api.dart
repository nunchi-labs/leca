import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'auth.dart';

class AuthApiException implements Exception {
  AuthApiException(this.code);

  final String code;
}

/// Talks to the Chow auth server. The app keeps its local mock when
/// [AuthConfig.apiBase] is empty.
class AuthApi {
  static Future<Map<String, Object?>> post(
    String path,
    Map<String, Object?> body,
  ) {
    return _send('POST', path, body);
  }

  static Future<Map<String, Object?>> get(String path) => _send('GET', path);

  static Future<Map<String, Object?>> finishProvider(String provider) async {
    final start = await post('/v1/auth/provider/start', {'provider': provider});
    final url = Uri.parse('${start['url']}');
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) throw AuthApiException('failed');
    final pending = '${start['pending']}';
    for (var i = 0; i < 180; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final status = await get('/v1/auth/pending/$pending');
      if (status['status'] == 'ready') return status;
      if (status['status'] == 'error') {
        throw AuthApiException('${status['error'] ?? 'failed'}');
      }
    }
    throw AuthApiException('failed');
  }

  static Future<Map<String, Object?>> _send(
    String method,
    String path, [
    Map<String, Object?>? body,
  ]) async {
    final uri = Uri.parse('${AuthConfig.apiBase}$path');
    final response = method == 'POST'
        ? await http.post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(body ?? const {}),
          )
        : await http.get(uri);
    final decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    if (decoded is! Map) throw AuthApiException('failed');
    final map = decoded.map((key, value) => MapEntry('$key', value));
    if (response.statusCode >= 400) {
      throw AuthApiException('${map['error'] ?? 'failed'}');
    }
    return map;
  }
}
