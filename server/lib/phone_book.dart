/// Who is reachable for a data call. The address is an iroh postcard,
/// refreshed by the device, and it expires so a stale route is not dialed.
class PhoneDirectory {
  PhoneDirectory({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static final shared = PhoneDirectory();

  static const ttl = Duration(seconds: 90);

  /// Same z-base-32 shape as an iroh endpoint id in the app.
  static final endpoint = RegExp(r'^[ybndrfg8ejkmcpqxot1uwisza345h769]{52}$');

  final DateTime Function() _now;
  final Map<String, PhoneListing> _byUser = {};

  bool publish({
    required String userId,
    required String name,
    required String endpoint,
    required String addr,
  }) {
    if (userId.isEmpty || !PhoneDirectory.endpoint.hasMatch(endpoint)) {
      return false;
    }
    if (addr.length < 8 || addr.length > 4000 || addr.contains(RegExp(r'\s'))) {
      return false;
    }
    _byUser[userId] = PhoneListing(
      name: _clip(name),
      endpoint: endpoint,
      addr: addr,
      at: _now(),
    );
    return true;
  }

  List<PhoneListing> find(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || q.length > 80) return const [];
    final now = _now();
    final hits = <PhoneListing>[];
    for (final listing in _byUser.values) {
      if (now.difference(listing.at) > ttl) continue;
      final name = listing.name.toLowerCase();
      final hit =
          listing.endpoint == query.trim() ||
          name == q ||
          (q.length >= 2 && name.contains(q));
      if (!hit) continue;
      hits.add(listing);
      if (hits.length == 8) break;
    }
    return hits;
  }

  PhoneListing? at(String endpoint) {
    final now = _now();
    for (final listing in _byUser.values) {
      if (listing.endpoint != endpoint) continue;
      if (now.difference(listing.at) > ttl) return null;
      return listing;
    }
    return null;
  }
}

class PhoneListing {
  const PhoneListing({
    required this.name,
    required this.endpoint,
    required this.addr,
    required this.at,
  });

  final String name;
  final String endpoint;
  final String addr;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'name': name,
    'endpoint': endpoint,
    'addr': addr,
  };
}

String _clip(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[\r\n]'), ' ').trim();
  if (cleaned.length <= 24) return cleaned;
  return cleaned.substring(0, 24);
}
