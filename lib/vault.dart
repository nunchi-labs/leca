import 'package:shared_preferences/shared_preferences.dart';

/// Where the app keeps its state between launches. One JSON document.
abstract class Vault {
  const Vault();

  Future<String?> read();

  Future<void> write(String json);
}

/// Tests and previews: nothing outlives the process.
class MemoryVault extends Vault {
  MemoryVault([this._json]);

  String? _json;

  String? get json => _json;

  @override
  Future<String?> read() async => _json;

  @override
  Future<void> write(String json) async => _json = json;
}

/// Phones, desktops, and the browser all keep the document locally.
class PrefsVault extends Vault {
  const PrefsVault({this.key = 'leca.state'});

  final String key;

  @override
  Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, json);
    } on Object catch (_) {}
  }
}
