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

  DriverProfile copyWith({bool? suspended}) {
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
    );
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
  });

  final String id;
  final String kind;
  final String category;
  final String subjectId;
  final String status;
  final String note;
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
  final int seq;
  final String prev;
  final String proof;
  final String stamp;
}

/// App fare, plus a price one side asked for. It is charged only after the
/// other side allows it. [proposer] is 'driver' or 'customer'.
class FareAsk {
  const FareAsk({
    required this.key,
    required this.appUsd,
    required this.askUsd,
    this.proposer = 'driver',
    this.allowed = false,
  });

  final String key;
  final double appUsd;
  final double askUsd;
  final String proposer;
  final bool allowed;

  FareAsk allow() => FareAsk(
    key: key,
    appUsd: appUsd,
    askUsd: askUsd,
    proposer: proposer,
    allowed: true,
  );
}
