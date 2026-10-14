/// Auth seams. Live keys are optional — the binary never requires them.
class AuthConfig {
  static const apiBase = String.fromEnvironment('AUTH_API');
  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const facebookAppId = String.fromEnvironment('FACEBOOK_APP_ID');
  static const smsAuth = String.fromEnvironment('SMS_AUTH');

  static bool get apiLive => apiBase.isNotEmpty;
  static bool get googleLive => apiLive || googleClientId.isNotEmpty;
  static bool get facebookLive => apiLive || facebookAppId.isNotEmpty;
  static bool get wechatLive => apiLive;
  static bool get smsLive => apiLive || smsAuth.isNotEmpty;

  static bool liveFor(String method) {
    switch (method) {
      case 'google':
        return googleLive;
      case 'facebook':
        return facebookLive;
      case 'wechat':
        return wechatLive;
      case 'phone':
        return smsLive;
      default:
        return false;
    }
  }
}

class Session {
  const Session({
    required this.id,
    required this.method,
    required this.displayName,
    required this.handle,
    this.token,
  });

  final String id;
  final String method;
  final String displayName;
  final String handle;
  final String? token;

  Map<String, Object?> toJson() => {
    'id': id,
    'method': method,
    'displayName': displayName,
    'handle': handle,
    'token': ?token,
  };

  static Session? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    final token = raw['token'];
    return Session(
      id: '${raw['id']}',
      method: '${raw['method']}',
      displayName: '${raw['displayName']}',
      handle: '${raw['handle']}',
      token: token == null ? null : '$token',
    );
  }
}

/// Opaque [kind] — restaurant, pharmacy, or any lawful string. Not an enum.
class BusinessListing {
  const BusinessListing({
    required this.id,
    required this.kind,
    required this.name,
    required this.cityId,
    this.note = '',
    this.openHour = 8,
    this.closeHour = 21,
    this.sellerName = '',
    this.sellerPhone = '',
    this.sellerId = '',
    this.latitude = 11.5564,
    this.longitude = 104.9282,
  });

  final String id;
  final String kind;
  final String name;
  final String cityId;
  final String note;
  final int openHour;
  final int closeHour;
  final String sellerName;
  final String sellerPhone;
  final String sellerId;
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'name': name,
    'cityId': cityId,
    'note': note,
    'openHour': openHour,
    'closeHour': closeHour,
    'sellerName': sellerName,
    'sellerPhone': sellerPhone,
    'sellerId': sellerId,
    'latitude': latitude,
    'longitude': longitude,
  };

  static BusinessListing? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    return BusinessListing(
      id: '${raw['id']}',
      kind: '${raw['kind']}',
      name: '${raw['name']}',
      cityId: '${raw['cityId']}',
      note: '${raw['note'] ?? ''}',
      openHour: _int(raw['openHour'], 8),
      closeHour: _int(raw['closeHour'], 21),
      sellerName: '${raw['sellerName'] ?? ''}',
      sellerPhone: '${raw['sellerPhone'] ?? ''}',
      sellerId: '${raw['sellerId'] ?? ''}',
      latitude: _double(raw['latitude'], 11.5564),
      longitude: _double(raw['longitude'], 104.9282),
    );
  }
}

int _int(Object? raw, int fallback) => raw is num ? raw.toInt() : fallback;

double _double(Object? raw, double fallback) =>
    raw is num ? raw.toDouble() : fallback;

/// Opaque [kind] — same rule as customer rentals.
class ListedVehicle {
  const ListedVehicle({
    required this.id,
    required this.kind,
    required this.withDriver,
    required this.autonomous,
    this.note = '',
    this.owner = false,
    this.latitude = 11.5564,
    this.longitude = 104.9282,
  });

  final String id;
  final String kind;
  final bool withDriver;
  final bool autonomous;
  final String note;
  final bool owner;
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'withDriver': withDriver,
    'autonomous': autonomous,
    'note': note,
    'owner': owner,
    'latitude': latitude,
    'longitude': longitude,
  };

  static ListedVehicle? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] == null) return null;
    return ListedVehicle(
      id: '${raw['id']}',
      kind: '${raw['kind']}',
      withDriver: raw['withDriver'] == true,
      autonomous: raw['autonomous'] == true,
      note: '${raw['note'] ?? ''}',
      owner: raw['owner'] == true,
      latitude: _double(raw['latitude'], 11.5564),
      longitude: _double(raw['longitude'], 104.9282),
    );
  }
}

/// Opaque [kind] — food, ride, send, or any lawful job string.
class OperatorJob {
  const OperatorJob({
    required this.id,
    required this.kind,
    required this.titleKm,
    required this.titleEn,
    required this.detailKm,
    required this.detailEn,
    required this.usd,
    this.status = 'open',
    this.latitude = 11.5564,
    this.longitude = 104.9282,
    this.room = '',
  });

  final String id;
  final String kind;
  final String titleKm;
  final String titleEn;
  final String detailKm;
  final String detailEn;
  final double usd;
  final String status;
  final double latitude;
  final double longitude;

  /// Chat room shared with the customer. Empty means a room of its own.
  final String room;

  String get talkRoom => room.isEmpty ? 'job:$id' : room;

  String titleFor(bool km) => km ? titleKm : titleEn;

  String detailFor(bool km) => km ? detailKm : detailEn;

  OperatorJob copyWith({String? status}) {
    return OperatorJob(
      id: id,
      kind: kind,
      titleKm: titleKm,
      titleEn: titleEn,
      detailKm: detailKm,
      detailEn: detailEn,
      usd: usd,
      status: status ?? this.status,
      latitude: latitude,
      longitude: longitude,
      room: room,
    );
  }
}
