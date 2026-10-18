import 'dart:convert';
import 'dart:typed_data';

import 'market.dart';
import 'records.dart';

/// Rules the app can enforce from MPWT Prakas 100, the May 2026
/// platform-only order, the e-commerce law, and the NBC payment rules.
/// Ministry filings themselves are not done in the client.
class CambodiaRules {
  static bool applies([MarketConfig? market]) =>
      (market ?? MarketConfig.active).countryCode == 'KH';

  /// A person's name is required only where the law names them.
  /// Cambodia's e-commerce law and the driver partner file do.
  /// A device key and a customer account do not.
  static bool requiresPersonalName([MarketConfig? market]) => applies(market);

  static String normKind(String kind) =>
      kind.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');

  static bool isBicycle(String kind) {
    final k = normKind(kind);
    return k == 'bicycle' || k == 'bike' || k == 'cycle';
  }

  static bool isMotorcycle(String kind) {
    final k = normKind(kind);
    return k == 'motorcycle' || k == 'motorbike' || k == 'moto';
  }

  static bool isTricycle(String kind) {
    final k = normKind(kind);
    return k == 'tuktuk' || k == 'tuk' || k == 'remorque' || k == 'tricycle';
  }

  static bool isMotorcycleWithTrailer(String kind) {
    final k = normKind(kind);
    return (k.contains('motorcycle') && k.contains('trailer')) ||
        k == 'motortrailer';
  }

  /// Technical inspection is not required for motorcycles.
  static bool needsInspection(String kind) {
    if (isBicycle(kind) ||
        isMotorcycle(kind) ||
        isMotorcycleWithTrailer(kind)) {
      return false;
    }
    return true;
  }

  /// Domestic transport certificate is not required for motorcycles,
  /// tricycles, or a motorcycle with a trailer.
  static bool needsDomesticCert(String kind) {
    if (isBicycle(kind) ||
        isMotorcycle(kind) ||
        isTricycle(kind) ||
        isMotorcycleWithTrailer(kind)) {
      return false;
    }
    return true;
  }

  static bool needsMotorFile(String kind) => !isBicycle(kind);

  /// The platform may partner with drivers. It may not operate the vehicle.
  static bool rejectsPlatformFleet({
    required bool autonomous,
    MarketConfig? market,
  }) => applies(market) && autonomous;

  static bool containsKhmer(String value) =>
      RegExp(r'[\u1780-\u17FF]').hasMatch(value);

  static bool refOk(String value) => value.trim().length >= 4;

  static String staffIdFor(String idNumber) {
    final digits = idNumber.replaceAll(RegExp(r'\D'), '');
    final tail = digits.length <= 6
        ? digits.padLeft(4, '0')
        : digits.substring(digits.length - 6);
    return 'LECA-KH-$tail';
  }

  static String? checkPartner({
    MarketConfig? market,
    required String vehicleKind,
    required String licenceNumber,
    required String plate,
    required String registration,
    required String inspection,
    required String domesticCert,
    required String insurance,
    required bool logoOnVehicle,
    required bool independentPartner,
    required bool trainedTrafficLaw,
    required bool trainedDriving,
    required bool trainedService,
    required bool trainedConduct,
  }) {
    if (!applies(market)) return null;
    if (!independentPartner) return 'partner_required';
    if (!trainedTrafficLaw ||
        !trainedDriving ||
        !trainedService ||
        !trainedConduct) {
      return 'training_required';
    }
    if (!needsMotorFile(vehicleKind)) return null;
    if (!refOk(licenceNumber)) return 'licence_invalid';
    if (!refOk(plate)) return 'plate_invalid';
    if (!refOk(registration)) return 'registration_invalid';
    if (needsInspection(vehicleKind) && !refOk(inspection)) {
      return 'inspection_invalid';
    }
    if (needsDomesticCert(vehicleKind) && !refOk(domesticCert)) {
      return 'transport_cert_invalid';
    }
    if (!refOk(insurance)) return 'insurance_invalid';
    if (!logoOnVehicle) return 'logo_required';
    return null;
  }

  static bool documentsReady(DriverProfile driver) {
    if (!driver.independentPartner || !driver.trained) return false;
    if (driver.review == 'pending' || driver.review == 'rejected') {
      return false;
    }
    if (!needsMotorFile(driver.vehicleKind)) return true;
    if (!refOk(driver.licenceNumber) ||
        !refOk(driver.plate) ||
        !refOk(driver.registration) ||
        !refOk(driver.insurance) ||
        !driver.logoOnVehicle) {
      return false;
    }
    if (driver.licencePhoto == null ||
        driver.registrationPhoto == null ||
        driver.insurancePhoto == null) {
      return false;
    }
    if (needsInspection(driver.vehicleKind) && !refOk(driver.inspection)) {
      return false;
    }
    if (needsDomesticCert(driver.vehicleKind) && !refOk(driver.domesticCert)) {
      return false;
    }
    return true;
  }

  static String? onlineBlock(DriverProfile? driver, [MarketConfig? market]) {
    if (!applies(market)) return null;
    if (driver == null || driver.suspended || !documentsReady(driver)) {
      return 'online_blocked';
    }
    return null;
  }

  static String? checkSeller({
    MarketConfig? market,
    required String sellerName,
    required String sellerPhone,
    required String sellerId,
  }) {
    if (!applies(market)) return null;
    final digits = sellerPhone.replaceAll(RegExp(r'\D'), '');
    final idDigits = sellerId.replaceAll(RegExp(r'\D'), '');
    if (sellerName.trim().isEmpty || digits.length < 8 || idDigits.length < 6) {
      return 'seller_kyc';
    }
    return null;
  }

  static String? checkItemText(String description, [MarketConfig? market]) {
    if (!applies(market)) return null;
    if (!containsKhmer(description)) return 'item_khmer';
    return null;
  }

  static RidePartner? match({
    required String vehicleKind,
    required Set<String> suspended,
    DriverProfile? driver,
  }) {
    final kind = normKind(vehicleKind);
    if (driver != null &&
        !driver.suspended &&
        !suspended.contains(driver.staffId) &&
        documentsReady(driver) &&
        normKind(driver.vehicleKind) == kind) {
      return RidePartner(
        id: driver.staffId,
        nameKm: driver.legalName,
        nameEn: driver.legalName,
        plate: driver.plate.isEmpty ? '—' : driver.plate,
        staffId: driver.staffId,
        vehicleKind: driver.vehicleKind,
        photo: driver.selfie,
      );
    }
    RidePartner? fallback;
    for (final sample in samplePartners) {
      if (suspended.contains(sample.id)) continue;
      fallback ??= sample;
      if (normKind(sample.vehicleKind) == kind) return sample;
    }
    return fallback;
  }

  static String shareText({
    required RidePartner? partner,
    required String cityName,
    required DateTime at,
    required String audience,
    double? latitude,
    double? longitude,
  }) {
    final location = latitude == null || longitude == null
        ? 'Location: unavailable'
        : 'Location: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    return [
      'Leca live trip ${partner?.id ?? '-'}',
      'Driver: ${partner?.nameEn ?? '-'}',
      'Plate: ${partner?.plate ?? '-'}',
      'Staff ID: ${partner?.staffId ?? '-'}',
      'City: $cityName',
      'Time: ${at.toUtc().toIso8601String()}',
      location,
      'For: $audience',
    ].join('\n');
  }
}

/// 1×1 portrait so a partner always has a photo widget before a real selfie.
final Uint8List kPartnerPortrait = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const samplePartners = <RidePartner>[
  RidePartner(
    id: 'p_moto',
    nameKm: 'ដារ៉ា កែម',
    nameEn: 'Dara Kem',
    plate: '2A-4521',
    staffId: 'LECA-KH-2041',
    vehicleKind: 'motorcycle',
  ),
  RidePartner(
    id: 'p_tuktuk',
    nameKm: 'សុខា មាស',
    nameEn: 'Sokha Meas',
    plate: '1A-8830',
    staffId: 'LECA-KH-1188',
    vehicleKind: 'tuktuk',
  ),
  RidePartner(
    id: 'p_remorque',
    nameKm: 'វណ្ណា រស់',
    nameEn: 'Vanna Ros',
    plate: '1A-2204',
    staffId: 'LECA-KH-2204',
    vehicleKind: 'remorque',
  ),
  RidePartner(
    id: 'p_car',
    nameKm: 'ចាន់ណា ហេង',
    nameEn: 'Channa Heng',
    plate: '2B-2201',
    staffId: 'LECA-KH-3302',
    vehicleKind: 'car',
  ),
  RidePartner(
    id: 'p_van',
    nameKm: 'បូរ៉ា សុខ',
    nameEn: 'Bora Sok',
    plate: '2C-7740',
    staffId: 'LECA-KH-7740',
    vehicleKind: 'van6',
  ),
  RidePartner(
    id: 'p_bike',
    nameKm: 'ម៉ាលី អ៊ុក',
    nameEn: 'Maly Ouk',
    plate: '—',
    staffId: 'LECA-KH-4410',
    vehicleKind: 'bicycle',
  ),
];
