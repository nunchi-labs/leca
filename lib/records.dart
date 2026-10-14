import 'dart:convert';
import 'dart:typed_data';

class DriverProfile {
  const DriverProfile({
    required this.legalName,
    required this.nameOnId,
    required this.idNumber,
    required this.phone,
    required this.vehicleKind,
    required this.selfie,
    required this.idCard,
    this.licenceNumber = '',
    this.plate = '',
    this.registration = '',
    this.inspection = '',
    this.domesticCert = '',
    this.insurance = '',
    this.logoOnVehicle = false,
    this.independentPartner = false,
    this.trained = false,
    this.staffId = '',
    this.suspended = false,
    this.licencePhoto,
    this.registrationPhoto,
    this.insurancePhoto,
    this.review = 'local',
    this.reviewNote = '',
  });

  final String legalName;
  final String nameOnId;
  final String idNumber;
  final String phone;
  final String vehicleKind;
  final Uint8List selfie;
  final Uint8List idCard;
  final String licenceNumber;
  final String plate;
  final String registration;
  final String inspection;
  final String domesticCert;
  final String insurance;
  final bool logoOnVehicle;
  final bool independentPartner;
  final bool trained;
  final String staffId;
  final bool suspended;
  final Uint8List? licencePhoto;
  final Uint8List? registrationPhoto;
  final Uint8List? insurancePhoto;

  /// local: no server yet. pending / approved / rejected: a person looked.
  final String review;
  final String reviewNote;

  Map<String, Object?> toJson() => {
    'legalName': legalName,
    'nameOnId': nameOnId,
    'idNumber': idNumber,
    'phone': phone,
    'vehicleKind': vehicleKind,
    'selfie': base64Encode(selfie),
    'idCard': base64Encode(idCard),
    'licenceNumber': licenceNumber,
    'plate': plate,
    'registration': registration,
    'inspection': inspection,
    'domesticCert': domesticCert,
    'insurance': insurance,
    'logoOnVehicle': logoOnVehicle,
    'independentPartner': independentPartner,
    'trained': trained,
    'staffId': staffId,
    'suspended': suspended,
    'licencePhoto': licencePhoto == null ? null : base64Encode(licencePhoto!),
    'registrationPhoto': registrationPhoto == null
        ? null
        : base64Encode(registrationPhoto!),
    'insurancePhoto': insurancePhoto == null
        ? null
        : base64Encode(insurancePhoto!),
    'review': review,
    'reviewNote': reviewNote,
  };

  static DriverProfile? fromJson(Object? raw) {
    if (raw is! Map) return null;
    try {
      return DriverProfile(
        legalName: '${raw['legalName']}',
        nameOnId: '${raw['nameOnId']}',
        idNumber: '${raw['idNumber']}',
        phone: '${raw['phone']}',
        vehicleKind: '${raw['vehicleKind']}',
        selfie: base64Decode('${raw['selfie']}'),
        idCard: base64Decode('${raw['idCard']}'),
        licenceNumber: '${raw['licenceNumber'] ?? ''}',
        plate: '${raw['plate'] ?? ''}',
        registration: '${raw['registration'] ?? ''}',
        inspection: '${raw['inspection'] ?? ''}',
        domesticCert: '${raw['domesticCert'] ?? ''}',
        insurance: '${raw['insurance'] ?? ''}',
        logoOnVehicle: raw['logoOnVehicle'] == true,
        independentPartner: raw['independentPartner'] == true,
        trained: raw['trained'] == true,
        staffId: '${raw['staffId'] ?? ''}',
        suspended: raw['suspended'] == true,
        licencePhoto: _bytes(raw['licencePhoto']),
        registrationPhoto: _bytes(raw['registrationPhoto']),
        insurancePhoto: _bytes(raw['insurancePhoto']),
        review: '${raw['review'] ?? 'local'}',
        reviewNote: '${raw['reviewNote'] ?? ''}',
      );
    } on FormatException {
      return null;
    }
  }

  DriverProfile copyWith({
    bool? suspended,
    String? review,
    String? reviewNote,
  }) {
    return DriverProfile(
      legalName: legalName,
      nameOnId: nameOnId,
      idNumber: idNumber,
      phone: phone,
      vehicleKind: vehicleKind,
      selfie: selfie,
      idCard: idCard,
      licenceNumber: licenceNumber,
      plate: plate,
      registration: registration,
      inspection: inspection,
      domesticCert: domesticCert,
      insurance: insurance,
      logoOnVehicle: logoOnVehicle,
      independentPartner: independentPartner,
      trained: trained,
      staffId: staffId,
      suspended: suspended ?? this.suspended,
      licencePhoto: licencePhoto,
      registrationPhoto: registrationPhoto,
      insurancePhoto: insurancePhoto,
      review: review ?? this.review,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

Uint8List? _bytes(Object? raw) {
  if (raw == null) return null;
  try {
    return base64Decode('$raw');
  } on FormatException {
    return null;
  }
}

/// Independent partner shown to a passenger. Not a Chow-owned vehicle.
class RidePartner {
  const RidePartner({
    required this.id,
    required this.nameKm,
    required this.nameEn,
    required this.plate,
    required this.staffId,
    required this.vehicleKind,
    this.photo,
  });

  final String id;
  final String nameKm;
  final String nameEn;
  final String plate;
  final String staffId;
  final String vehicleKind;
  final Uint8List? photo;

  String nameFor(String languageCode) => languageCode == 'km' ? nameKm : nameEn;
}

class TripShare {
  const TripShare({
    required this.audience,
    required this.text,
    required this.at,
    required this.hasLocation,
  });

  final String audience;
  final String text;
  final DateTime at;
  final bool hasLocation;
}

class PlatformReport {
  const PlatformReport({
    required this.id,
    required this.kind,
    required this.category,
    required this.subjectId,
    required this.status,
    this.note = '',
    this.appeal = '',
  });

  final String id;
  final String kind;
  final String category;
  final String subjectId;
  final String status;
  final String note;
  final String appeal;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'category': category,
    'subjectId': subjectId,
    'status': status,
    'note': note,
    'appeal': appeal,
  };

  static PlatformReport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return PlatformReport(
      id: '${raw['id']}',
      kind: '${raw['kind']}',
      category: '${raw['category']}',
      subjectId: '${raw['subjectId']}',
      status: '${raw['status']}',
      note: '${raw['note'] ?? ''}',
      appeal: '${raw['appeal'] ?? ''}',
    );
  }

  PlatformReport copyWith({String? status, String? appeal}) => PlatformReport(
    id: id,
    kind: kind,
    category: category,
    subjectId: subjectId,
    status: status ?? this.status,
    note: note,
    appeal: appeal ?? this.appeal,
  );
}

/// A vendor item is a photo, a short description, and a price.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.businessId,
    required this.description,
    required this.usd,
    required this.photo,
    this.removed = false,
  });

  final String id;
  final String businessId;
  final String description;
  final double usd;
  final Uint8List photo;
  final bool removed;

  Map<String, Object?> toJson() => {
    'id': id,
    'businessId': businessId,
    'description': description,
    'usd': usd,
    'photo': base64Encode(photo),
    'removed': removed,
  };

  static ShopItem? fromJson(Object? raw) {
    if (raw is! Map || raw['usd'] is! num) return null;
    try {
      return ShopItem(
        id: '${raw['id']}',
        businessId: '${raw['businessId']}',
        description: '${raw['description']}',
        usd: (raw['usd'] as num).toDouble(),
        photo: base64Decode('${raw['photo']}'),
        removed: raw['removed'] == true,
      );
    } on FormatException {
      return null;
    }
  }

  ShopItem takeDown() => ShopItem(
    id: id,
    businessId: businessId,
    description: description,
    usd: usd,
    photo: photo,
    removed: true,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.placeId,
    required this.text,
    required this.asBusiness,
    required this.at,
    this.kind = 'text',
    this.name = '',
    this.who = '',
    this.seq = 0,
    this.prev = '',
    this.proof = '',
    this.stamp = '',
  });

  final String id;
  final String placeId;
  final String text;
  final bool asBusiness;
  final DateTime at;
  final String kind;
  final String name;

  /// Who said it: a short hash of the account id, never the id itself.
  final String who;
  final int seq;
  final String prev;
  final String proof;
  final String stamp;

  Map<String, Object?> toJson() => {
    'id': id,
    'placeId': placeId,
    'text': text,
    'asBusiness': asBusiness,
    'at': at.toUtc().toIso8601String(),
    'kind': kind,
    'name': name,
    'who': who,
    'seq': seq,
    'prev': prev,
    'proof': proof,
    'stamp': stamp,
  };

  static ChatMessage? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final at = DateTime.tryParse('${raw['at']}');
    if (at == null) return null;
    return ChatMessage(
      id: '${raw['id']}',
      placeId: '${raw['placeId']}',
      text: '${raw['text']}',
      asBusiness: raw['asBusiness'] == true,
      at: at.toLocal(),
      kind: '${raw['kind'] ?? 'text'}',
      name: '${raw['name'] ?? ''}',
      who: '${raw['who'] ?? ''}',
      seq: raw['seq'] is int ? raw['seq'] as int : 0,
      prev: '${raw['prev'] ?? ''}',
      proof: '${raw['proof'] ?? ''}',
      stamp: '${raw['stamp'] ?? ''}',
    );
  }
}

/// One price named during a bargain. [side] is 'driver' or 'customer'.
class FareBid {
  const FareBid({required this.usd, required this.side});

  final double usd;
  final String side;

  Map<String, Object?> toJson() => {'usd': usd, 'side': side};

  static FareBid? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final usd = raw['usd'];
    if (usd is! num) return null;
    return FareBid(usd: usd.toDouble(), side: '${raw['side']}');
  }
}

/// A bargain over one fare. The app price is charged until a bid is
/// allowed. Either side may keep bidding until one of them ends it.
class FareAsk {
  const FareAsk({
    required this.key,
    required this.appUsd,
    this.bids = const [],
    this.pending,
    this.agreedUsd,
    this.ended = false,
  });

  final String key;
  final double appUsd;

  /// Every bid in order, so the whole bargain can be read back.
  final List<FareBid> bids;

  /// The bid the other side has not answered yet.
  final FareBid? pending;

  /// The last price both sides agreed on.
  final double? agreedUsd;

  /// One side closed the bargain. [agreedUsd] or the app price stands.
  final bool ended;

  bool get open => pending != null && !ended;

  /// What is charged right now.
  double get usd => agreedUsd ?? appUsd;

  /// A bid from [side] puts the ball in the other court and reopens an
  /// ended bargain.
  FareAsk bid(double usd, String side) => FareAsk(
    key: key,
    appUsd: appUsd,
    bids: [
      ...bids,
      FareBid(usd: usd, side: side),
    ],
    pending: FareBid(usd: usd, side: side),
    agreedUsd: agreedUsd,
    ended: false,
  );

  FareAsk allow() {
    final bid = pending;
    if (bid == null) return this;
    return FareAsk(
      key: key,
      appUsd: appUsd,
      bids: bids,
      pending: null,
      agreedUsd: bid.usd,
      ended: ended,
    );
  }

  FareAsk end() => FareAsk(
    key: key,
    appUsd: appUsd,
    bids: bids,
    pending: null,
    agreedUsd: agreedUsd,
    ended: true,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'appUsd': appUsd,
    'bids': [for (final bid in bids) bid.toJson()],
    'pending': pending?.toJson(),
    'agreedUsd': agreedUsd,
    'ended': ended,
  };

  static FareAsk? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final appUsd = raw['appUsd'];
    if (appUsd is! num) return null;
    final rawBids = raw['bids'];
    final agreed = raw['agreedUsd'];
    return FareAsk(
      key: '${raw['key']}',
      appUsd: appUsd.toDouble(),
      bids: [
        if (rawBids is List)
          for (final item in rawBids)
            if (FareBid.fromJson(item) != null) FareBid.fromJson(item)!,
      ],
      pending: FareBid.fromJson(raw['pending']),
      agreedUsd: agreed is num ? agreed.toDouble() : null,
      ended: raw['ended'] == true,
    );
  }
}
