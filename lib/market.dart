import 'package:flutter/material.dart';

/// One global product: Leca. Cambodia is the test market, not the ceiling.
class MarketConfig {
  const MarketConfig({
    required this.countryCode,
    required this.defaultLocale,
    required this.cities,
    required this.defaultCityId,
    required this.currencyCode,
    required this.currencyNumeric,
    required this.usdToLocal,
    this.localPrefix = '៛',
    required this.merchantName,
    required this.defaultRailId,
    required this.rails,
    required this.exampleVehicles,
    this.isTestMarket = false,
  });

  static const brand = 'Leca';

  final String countryCode;
  final Locale defaultLocale;
  final List<City> cities;
  final String defaultCityId;
  final String currencyCode;
  final int currencyNumeric;
  final double usdToLocal;
  final String localPrefix;
  final String merchantName;
  final String defaultRailId;
  final List<PaymentRail> rails;
  final List<VehicleOffer> exampleVehicles;
  final bool isTestMarket;

  City city(String id) => cities.firstWhere((c) => c.id == id);

  PaymentRail get defaultRail => railById(defaultRailId);

  PaymentRail railById(String id) =>
      rails.firstWhere((r) => r.id == id, orElse: () => rails.first);

  List<VehicleOffer> get regularVehicles =>
      exampleVehicles.where((v) => !v.autonomous).toList();

  List<VehicleOffer> get autonomousVehicles =>
      exampleVehicles.where((v) => v.autonomous).toList();

  /// Cambodia is the only market for now.
  static const cambodia = MarketConfig(
    countryCode: 'KH',
    defaultLocale: Locale('km'),
    defaultCityId: 'phnom_penh',
    isTestMarket: true,
    cities: _provinces,
    currencyCode: 'USD',
    currencyNumeric: 840,
    usdToLocal: 4100,
    merchantName: 'LECA',
    defaultRailId: 'aba',
    rails: [
      PaymentRail(
        id: 'aba',
        nameKm: 'ABA Pay',
        nameEn: 'ABA Pay',
        kind: RailKind.khqr,
        bakongAccountId: 'leca.kh@abaa',
        acquiringBank: 'ABA Bank',
      ),
      PaymentRail(
        id: 'bakong',
        nameKm: 'Bakong KHQR',
        nameEn: 'Bakong KHQR',
        kind: RailKind.khqr,
        bakongAccountId: 'leca.kh@bakong',
        acquiringBank: 'Bakong',
      ),
      PaymentRail(
        id: 'acleda',
        nameKm: 'ACLEDA',
        nameEn: 'ACLEDA',
        kind: RailKind.khqr,
        bakongAccountId: 'leca.kh@aclb',
        acquiringBank: 'ACLEDA Bank',
      ),
      PaymentRail(
        id: 'wingbank',
        nameKm: 'Wing Bank',
        nameEn: 'Wing Bank',
        kind: RailKind.khqr,
        bakongAccountId: 'leca.kh@wing',
        acquiringBank: 'Wing Bank',
      ),
      PaymentRail(
        id: 'cash',
        nameKm: 'សាច់ប្រាក់',
        nameEn: 'Cash',
        kind: RailKind.cash,
      ),
      ...stripeCards,
      ...chinesePayments,
    ],
    exampleVehicles: _partnerWheels,
  );

  static const current = cambodia;

  static MarketConfig get active => current;
}

/// Every province. Phnom Penh and Siem Reap stay first because they have kitchens.
const _provinces = <City>[
  City(
    id: 'phnom_penh',
    nameKm: 'ភ្នំពេញ',
    nameEn: 'Phnom Penh',
    latitude: 11.5564,
    longitude: 104.9282,
  ),
  City(
    id: 'siem_reap',
    nameKm: 'សៀមរាប',
    nameEn: 'Siem Reap',
    latitude: 13.3633,
    longitude: 103.8564,
  ),
  City(
    id: 'banteay_meanchey',
    nameKm: 'បន្ទាយមានជ័យ',
    nameEn: 'Banteay Meanchey',
    latitude: 13.7530,
    longitude: 102.9896,
  ),
  City(
    id: 'battambang',
    nameKm: 'បាត់ដំបង',
    nameEn: 'Battambang',
    latitude: 13.0957,
    longitude: 103.2022,
  ),
  City(
    id: 'kampong_cham',
    nameKm: 'កំពង់ចាម',
    nameEn: 'Kampong Cham',
    latitude: 11.9934,
    longitude: 105.4635,
  ),
  City(
    id: 'kampong_chhnang',
    nameKm: 'កំពង់ឆ្នាំង',
    nameEn: 'Kampong Chhnang',
    latitude: 12.2500,
    longitude: 104.6667,
  ),
  City(
    id: 'kampong_speu',
    nameKm: 'កំពង់ស្ពឺ',
    nameEn: 'Kampong Speu',
    latitude: 11.4536,
    longitude: 104.5208,
  ),
  City(
    id: 'kampong_thom',
    nameKm: 'កំពង់ធំ',
    nameEn: 'Kampong Thom',
    latitude: 12.7111,
    longitude: 104.8887,
  ),
  City(
    id: 'kampot',
    nameKm: 'កំពត',
    nameEn: 'Kampot',
    latitude: 10.6104,
    longitude: 104.1815,
  ),
  City(
    id: 'kandal',
    nameKm: 'កណ្ដាល',
    nameEn: 'Kandal',
    latitude: 11.4833,
    longitude: 104.9500,
  ),
  City(
    id: 'kep',
    nameKm: 'កែប',
    nameEn: 'Kep',
    latitude: 10.4829,
    longitude: 104.3167,
  ),
  City(
    id: 'koh_kong',
    nameKm: 'កោះកុង',
    nameEn: 'Koh Kong',
    latitude: 11.6153,
    longitude: 102.9839,
  ),
  City(
    id: 'kratie',
    nameKm: 'ក្រចេះ',
    nameEn: 'Kratie',
    latitude: 12.4889,
    longitude: 106.0189,
  ),
  City(
    id: 'mondulkiri',
    nameKm: 'មណ្ឌលគិរី',
    nameEn: 'Mondulkiri',
    latitude: 12.4558,
    longitude: 107.1881,
  ),
  City(
    id: 'oddar_meanchey',
    nameKm: 'ឧត្តរមានជ័យ',
    nameEn: 'Oddar Meanchey',
    latitude: 14.1818,
    longitude: 103.5170,
  ),
  City(
    id: 'pailin',
    nameKm: 'ប៉ៃលិន',
    nameEn: 'Pailin',
    latitude: 12.8492,
    longitude: 102.6093,
  ),
  City(
    id: 'preah_sihanouk',
    nameKm: 'ព្រះសីហនុ',
    nameEn: 'Preah Sihanouk',
    latitude: 10.6278,
    longitude: 103.5224,
  ),
  City(
    id: 'preah_vihear',
    nameKm: 'ព្រះវិហារ',
    nameEn: 'Preah Vihear',
    latitude: 13.8073,
    longitude: 104.9740,
  ),
  City(
    id: 'prey_veng',
    nameKm: 'ព្រៃវែង',
    nameEn: 'Prey Veng',
    latitude: 11.4868,
    longitude: 105.3253,
  ),
  City(
    id: 'pursat',
    nameKm: 'ពោធិ៍សាត់',
    nameEn: 'Pursat',
    latitude: 12.5388,
    longitude: 103.9192,
  ),
  City(
    id: 'ratanakiri',
    nameKm: 'រតនគិរី',
    nameEn: 'Ratanakiri',
    latitude: 13.7394,
    longitude: 106.9873,
  ),
  City(
    id: 'stung_treng',
    nameKm: 'ស្ទឹងត្រែង',
    nameEn: 'Stung Treng',
    latitude: 13.5259,
    longitude: 105.9683,
  ),
  City(
    id: 'svay_rieng',
    nameKm: 'ស្វាយរៀង',
    nameEn: 'Svay Rieng',
    latitude: 11.0878,
    longitude: 105.7993,
  ),
  City(
    id: 'takeo',
    nameKm: 'តាកែវ',
    nameEn: 'Takeo',
    latitude: 10.9908,
    longitude: 104.7850,
  ),
  City(
    id: 'tboung_khmum',
    nameKm: 'ត្បូងឃ្មុំ',
    nameEn: 'Tboung Khmum',
    latitude: 11.9833,
    longitude: 105.6500,
  ),
];

const _partnerWheels = <VehicleOffer>[
  VehicleOffer(
    id: 'motorcycle',
    nameKm: 'ម៉ូតូ',
    nameEn: 'Motorcycle',
    usd: 1.20,
    rentUsd: 8,
    saleUsd: 900,
  ),
  VehicleOffer(
    id: 'tuktuk',
    nameKm: 'ទូកទូក',
    nameEn: 'Tuktuk',
    usd: 1.80,
    rentUsd: 12,
    saleUsd: 2500,
  ),
  VehicleOffer(
    id: 'bicycle',
    nameKm: 'កង់',
    nameEn: 'Bicycle',
    usd: 0.80,
    rentUsd: 3,
    saleUsd: 80,
  ),
  VehicleOffer(id: 'remorque', nameKm: 'រម៉ក', nameEn: 'Remorque'),
  VehicleOffer(
    id: 'car',
    nameKm: 'ឡាន',
    nameEn: 'Car',
    usd: 2.50,
    rentUsd: 28,
    saleUsd: 12000,
  ),
  VehicleOffer(
    id: 'van6',
    nameKm: 'ឡាន ៦ នាក់',
    nameEn: '6-person car',
    usd: 3,
  ),
];

class City {
  const City({
    required this.id,
    required this.nameKm,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String nameKm;
  final String nameEn;
  final double latitude;
  final double longitude;

  String nameFor(Locale locale) =>
      locale.languageCode == 'km' ? nameKm : nameEn;
}

/// Opaque [id] so a new legal type never needs an enum change.
class VehicleOffer {
  const VehicleOffer({
    required this.id,
    required this.nameKm,
    required this.nameEn,
    this.withDriver = true,
    this.selfDrive = true,
    this.autonomous = false,
    this.usd = 1.80,
    this.rentUsd,
    this.saleUsd,
  });

  final String id;
  final String nameKm;
  final String nameEn;
  final bool withDriver;
  final bool selfDrive;
  final bool autonomous;

  /// Ride price set by the app.
  final double usd;
  final double? rentUsd;
  final double? saleUsd;

  double get rentPrice => rentUsd ?? usd + 4;

  double get salePrice => saleUsd ?? usd * 400;

  String nameFor(Locale locale) =>
      locale.languageCode == 'km' ? nameKm : nameEn;
}

enum RailKind { stripe, khqr, generic, cash }

/// Card networks Stripe Checkout accepts. One rail each, same processor.
const stripeCards = <PaymentRail>[
  PaymentRail(
    id: 'visa',
    nameKm: 'Visa',
    nameEn: 'Visa',
    kind: RailKind.stripe,
  ),
  PaymentRail(
    id: 'mastercard',
    nameKm: 'Mastercard',
    nameEn: 'Mastercard',
    kind: RailKind.stripe,
  ),
  PaymentRail(
    id: 'discover',
    nameKm: 'Discover',
    nameEn: 'Discover',
    kind: RailKind.stripe,
  ),
];

/// UnionPay is the Chinese card network. Alipay is the largest Chinese wallet.
const chinesePayments = <PaymentRail>[
  PaymentRail(
    id: 'unionpay',
    nameKm: 'UnionPay',
    nameEn: 'UnionPay',
    kind: RailKind.stripe,
  ),
  PaymentRail(
    id: 'alipay',
    nameKm: 'Alipay',
    nameEn: 'Alipay',
    kind: RailKind.stripe,
  ),
];

/// Open payment list. Add a KHQR bank or a card network as another row.
class PaymentRail {
  const PaymentRail({
    required this.id,
    required this.nameKm,
    required this.nameEn,
    required this.kind,
    this.bakongAccountId,
    this.acquiringBank,
  });

  final String id;
  final String nameKm;
  final String nameEn;
  final RailKind kind;
  final String? bakongAccountId;
  final String? acquiringBank;

  String nameFor(Locale locale) =>
      locale.languageCode == 'km' ? nameKm : nameEn;
}

enum PopularWindow { hour, day, week, month }

enum BookKind { ride, rent, send, goods }

class Booking {
  const Booking({
    required this.kind,
    required this.title,
    required this.amountUsd,
    this.detail = '',
    this.vehicleId = '',
    this.meters = 0,
    this.minutes = 0,
    this.hours = 0,
    this.proof = '',
    this.card = 'leca-kh-1',
  });

  final BookKind kind;
  final String title;
  final double amountUsd;
  final String detail;
  final String vehicleId;
  final int meters;
  final int minutes;

  /// Rental length. Zero for rides and deliveries.
  final int hours;
  final String proof;

  /// The rate card the proof was made under.
  final String card;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'title': title,
    'amountUsd': amountUsd,
    'detail': detail,
    'vehicleId': vehicleId,
    'meters': meters,
    'minutes': minutes,
    'hours': hours,
    'proof': proof,
    'card': card,
  };

  static Booking? fromJson(Object? raw) {
    if (raw is! Map || raw['amountUsd'] is! num) return null;
    final kind = BookKind.values.where((k) => k.name == raw['kind']);
    if (kind.isEmpty) return null;
    return Booking(
      kind: kind.first,
      title: '${raw['title']}',
      amountUsd: (raw['amountUsd'] as num).toDouble(),
      detail: '${raw['detail'] ?? ''}',
      vehicleId: '${raw['vehicleId'] ?? ''}',
      meters: raw['meters'] is num ? (raw['meters'] as num).toInt() : 0,
      minutes: raw['minutes'] is num ? (raw['minutes'] as num).toInt() : 0,
      hours: raw['hours'] is num ? (raw['hours'] as num).toInt() : 0,
      proof: '${raw['proof'] ?? ''}',
      card: '${raw['card'] ?? 'leca-kh-1'}',
    );
  }
}

/// Leca's fee on every sale: food, delivery, rides, rentals, and shop goods.
const saleFeeRate = 0.05;

double saleFeeUsd(double usd) {
  if (usd <= 0) return 0;
  final cents = (usd * 100).round();
  return (cents * 5 / 100).round() / 100;
}

String moneyUsd(double amount) => '\$${amount.toStringAsFixed(2)}';

String moneyKhr(double usd) {
  final market = MarketConfig.active;
  return '${market.localPrefix}${(usd * market.usdToLocal).round()}';
}
