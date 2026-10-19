import 'package:flutter/widgets.dart';

import 'compliance.dart';
import 'geo.dart';
import 'market.dart';
import 'quote.dart';

/// Voice costs nothing. iroh on the device carries it.
const irohCallUsd = 0.0;

/// People reach each other through iroh, not a carrier circuit.
const userComms = 'iroh';

/// One order, or a borey, a fleet, a season. The cap is the extreme end.
const maxBulk = 1000000;

/// One incident can need more than one ambulance. It is not a million.
const maxAmbulances = 12;

int clampQty(int n, {required int max}) {
  if (n < 1) return 1;
  if (n > max) return max;
  return n;
}

double bulkUsd(double unit, int count) {
  final n = clampQty(count, max: maxBulk);
  final cents = (unit * 100).round();
  return cents * n / 100;
}

/// A parcel run holds twenty units. Past that, another run is billed.
int haulCount(int count) {
  final n = clampQty(count, max: maxBulk);
  return (n + 19) ~/ 20;
}

double landedUsd({
  required double unit,
  required int count,
  required double shipOnce,
}) {
  final n = clampQty(count, max: maxBulk);
  return bulkUsd(unit, n) + bulkUsd(shipOnce, haulCount(n));
}

String pick(BuildContext context, String km, String en) =>
    Localizations.localeOf(context).languageCode == 'km' ? km : en;

String clock(BuildContext context, int minutes) {
  if (minutes < 60) {
    return pick(context, '$minutes នាទី', '$minutes min');
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) {
    return pick(context, '$hours ម៉ោង', '$hours h');
  }
  return pick(context, '$hours ម៉ោង $rest នាទី', '$hours h $rest m');
}

enum Medium { fiber, cable }

class FiberPlan {
  const FiberPlan({
    required this.id,
    required this.brand,
    required this.brandKm,
    required this.medium,
    required this.usd,
    this.gbps = 10,
  });

  final String id;
  final String brand;
  final String brandKm;
  final Medium medium;
  final double usd;
  final int gbps;

  String nameFor(BuildContext context) => pick(context, brandKm, brand);
}

/// Licensed internet and cable operators, sold as a 10 Gbps line
/// in every populated center. Names follow the TRC operator list
/// (Open Development Cambodia, through August 2025).
const fiberPlans = <FiberPlan>[
  FiberPlan(
    id: 'cfocn',
    brand: 'CFOCN',
    brandKm: 'CFOCN',
    medium: Medium.cable,
    usd: 79,
  ),
  FiberPlan(
    id: 'angkor_cable',
    brand: 'Angkor Cable',
    brandKm: 'អង្គរខេបល',
    medium: Medium.cable,
    usd: 35,
  ),
  FiberPlan(
    id: 'mekongnet',
    brand: 'MekongNet',
    brandKm: 'មេគង្គណិត',
    medium: Medium.fiber,
    usd: 55,
  ),
  FiberPlan(
    id: 'adi',
    brand: 'Angkor Data Infrastructure',
    brandKm: 'អង្គរដាតា',
    medium: Medium.fiber,
    usd: 60,
  ),
  FiberPlan(
    id: 'bee',
    brand: 'Bee Union',
    brandKm: 'ប៊ីយូនីយ៉ន',
    medium: Medium.fiber,
    usd: 32,
  ),
  FiberPlan(
    id: 'bighub',
    brand: 'BigHub',
    brandKm: 'ប៊ីកហាប់',
    medium: Medium.fiber,
    usd: 29,
  ),
  FiberPlan(
    id: 'china_telecom',
    brand: 'China Telecom',
    brandKm: 'ចាយណា ថេលីខម',
    medium: Medium.fiber,
    usd: 70,
  ),
  FiberPlan(
    id: 'ntt',
    brand: 'NTT',
    brandKm: 'NTT',
    medium: Medium.fiber,
    usd: 75,
  ),
  FiberPlan(
    id: 'cambo_tech',
    brand: 'Cambo Technology',
    brandKm: 'ខេមបូ តិច',
    medium: Medium.fiber,
    usd: 34,
  ),
  FiberPlan(
    id: 'cellcard',
    brand: 'Cellcard',
    brandKm: 'សែលកាត',
    medium: Medium.fiber,
    usd: 45,
  ),
  FiberPlan(
    id: 'camintel',
    brand: 'Camintel',
    brandKm: 'កាំមីនថែល',
    medium: Medium.fiber,
    usd: 40,
  ),
  FiberPlan(
    id: 'china_unicom',
    brand: 'China Unicom',
    brandKm: 'ចាយណា យូនីខម',
    medium: Medium.fiber,
    usd: 68,
  ),
  FiberPlan(
    id: 'citylink',
    brand: 'Citylink',
    brandKm: 'ស៊ីធីលីង',
    medium: Medium.fiber,
    usd: 36,
  ),
  FiberPlan(
    id: 'online',
    brand: 'Online',
    brandKm: 'អនឡាញ',
    medium: Medium.fiber,
    usd: 38,
  ),
  FiberPlan(
    id: 'empire',
    brand: 'Empire Tech',
    brandKm: 'អ៊ែមភាយ',
    medium: Medium.fiber,
    usd: 30,
  ),
  FiberPlan(
    id: 'ezecom',
    brand: 'Ezecom',
    brandKm: 'អ៊ីហ្ស៊ីខម',
    medium: Medium.fiber,
    usd: 85,
  ),
  FiberPlan(
    id: 'fastone',
    brand: 'Fast One',
    brandKm: 'ហ្វាសវ៉ាន់',
    medium: Medium.fiber,
    usd: 28,
  ),
  FiberPlan(
    id: 'fiber_nanotech',
    brand: 'Fiber Nanotech',
    brandKm: 'ហ្វាយប័រ ណាណូតិច',
    medium: Medium.fiber,
    usd: 33,
  ),
  FiberPlan(
    id: 'maxbit',
    brand: 'MAXBIT',
    brandKm: 'ម៉ាក់ប៊ីត',
    medium: Medium.fiber,
    usd: 31,
  ),
  FiberPlan(
    id: 'mega_truenet',
    brand: 'Mega Truenet',
    brandKm: 'មេហ្គា ធូណិត',
    medium: Medium.fiber,
    usd: 34,
  ),
  FiberPlan(
    id: 'micromax',
    brand: 'Micromax',
    brandKm: 'មីក្រូម៉ាក់',
    medium: Medium.cable,
    usd: 27,
  ),
  FiberPlan(
    id: 'monorom',
    brand: 'Monorom',
    brandKm: 'មនោរម្យ',
    medium: Medium.fiber,
    usd: 30,
  ),
  FiberPlan(
    id: 'neocom',
    brand: 'NeocomISP',
    brandKm: 'ណេអូខម',
    medium: Medium.fiber,
    usd: 80,
  ),
  FiberPlan(
    id: 'nsm',
    brand: 'NSM',
    brandKm: 'NSM',
    medium: Medium.fiber,
    usd: 29,
  ),
  FiberPlan(
    id: 'ppctv',
    brand: 'PPCTV',
    brandKm: 'ភីភីស៊ីធីវី',
    medium: Medium.cable,
    usd: 32,
  ),
  FiberPlan(
    id: 'sinet',
    brand: 'SINET',
    brandKm: 'ស៊ីណិត',
    medium: Medium.fiber,
    usd: 78,
  ),
  FiberPlan(
    id: 'smart',
    brand: 'Smart',
    brandKm: 'ស្មាត',
    medium: Medium.fiber,
    usd: 42,
  ),
  FiberPlan(
    id: 'seatel',
    brand: 'SEATEL',
    brandKm: 'ស៊ីថែល',
    medium: Medium.fiber,
    usd: 40,
  ),
  FiberPlan(
    id: 'spidernet',
    brand: 'Spidernet',
    brandKm: 'ស្ពាយឌើណិត',
    medium: Medium.fiber,
    usd: 36,
  ),
  FiberPlan(
    id: 'telcotech',
    brand: 'Telcotech',
    brandKm: 'តែលកូតិច',
    medium: Medium.fiber,
    usd: 72,
  ),
  FiberPlan(
    id: 'telecom_cambodia',
    brand: 'Telecom Cambodia',
    brandKm: 'ទូរគមនាគមន៍កម្ពុជា',
    medium: Medium.fiber,
    usd: 38,
  ),
  FiberPlan(
    id: 'telnet',
    brand: 'Telnet',
    brandKm: 'តែលណិត',
    medium: Medium.fiber,
    usd: 33,
  ),
  FiberPlan(
    id: 'time',
    brand: 'TIME',
    brandKm: 'TIME',
    medium: Medium.fiber,
    usd: 48,
  ),
  FiberPlan(
    id: 'today',
    brand: 'Today',
    brandKm: 'ធូដេ',
    medium: Medium.fiber,
    usd: 35,
  ),
  FiberPlan(
    id: 'tonle',
    brand: 'Tonle',
    brandKm: 'ទន្លេ',
    medium: Medium.fiber,
    usd: 30,
  ),
  FiberPlan(
    id: 'turbotech',
    brand: 'Turbotech',
    brandKm: 'ទួបូតិច',
    medium: Medium.fiber,
    usd: 34,
  ),
  FiberPlan(
    id: 'metfone',
    brand: 'Metfone',
    brandKm: 'ម៉ិតហ្វូន',
    medium: Medium.fiber,
    usd: 39,
  ),
  FiberPlan(
    id: 'vonet',
    brand: 'Vonet',
    brandKm: 'វីណិត',
    medium: Medium.fiber,
    usd: 28,
  ),
  FiberPlan(
    id: 'wicam',
    brand: 'Wicam',
    brandKm: 'វីខេម',
    medium: Medium.fiber,
    usd: 37,
  ),
  FiberPlan(
    id: 'wingel',
    brand: 'Wingel',
    brandKm: 'វីងហ្គែល',
    medium: Medium.fiber,
    usd: 29,
  ),
  FiberPlan(
    id: 'camko',
    brand: 'Camko City',
    brandKm: 'កាំកូ',
    medium: Medium.fiber,
    usd: 44,
  ),
  FiberPlan(
    id: 'xinwei',
    brand: 'Xinwei',
    brandKm: 'ស៊ីនវ៉េ',
    medium: Medium.fiber,
    usd: 31,
  ),
  FiberPlan(
    id: 'ztnet',
    brand: 'Ztnet',
    brandKm: 'ហ្សេតណិត',
    medium: Medium.fiber,
    usd: 27,
  ),
  FiberPlan(
    id: 'singmeng',
    brand: 'Singmeng',
    brandKm: 'ស៊ីងម៉េង',
    medium: Medium.cable,
    usd: 33,
  ),
  FiberPlan(
    id: 'gbnet',
    brand: 'Gb Net',
    brandKm: 'ជីប៊ីណិត',
    medium: Medium.fiber,
    usd: 36,
  ),
  FiberPlan(
    id: 'kingtel',
    brand: 'Kingtel',
    brandKm: 'ឃីងតែល',
    medium: Medium.fiber,
    usd: 32,
  ),
  FiberPlan(
    id: 'sabay',
    brand: 'Sabay',
    brandKm: 'សប្បាយ',
    medium: Medium.fiber,
    usd: 30,
  ),
  FiberPlan(
    id: 'metfone_net',
    brand: 'Metfone Network',
    brandKm: 'បណ្តាញម៉ិតហ្វូន',
    medium: Medium.cable,
    usd: 41,
  ),
];

class HomeHotspot {
  const HomeHotspot({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    required this.usd,
  });

  final String id;
  final String nameEn;
  final String nameKm;
  final double usd;

  String get mobile => '5G+';

  String nameFor(BuildContext context) => pick(context, nameKm, nameEn);
}

const homeHotspots = <HomeHotspot>[
  HomeHotspot(
    id: 'cpe_in',
    nameEn: 'Home 5G+ indoor',
    nameKm: 'ហតស្ប៉ត 5G+ ក្នុងផ្ទះ',
    usd: 69,
  ),
  HomeHotspot(
    id: 'cpe_out',
    nameEn: 'Home 5G+ outdoor',
    nameKm: 'ហតស្ប៉ត 5G+ ក្រៅផ្ទះ',
    usd: 119,
  ),
  HomeHotspot(
    id: 'cpe_desk',
    nameEn: 'Desk 5G+ router',
    nameKm: 'រ៉ោតទ័រ 5G+ លើតុ',
    usd: 89,
  ),
];

class HostNet {
  const HostNet({required this.id, required this.nameEn, required this.nameKm});

  final String id;
  final String nameEn;
  final String nameKm;

  String nameFor(BuildContext context) => pick(context, nameKm, nameEn);
}

/// The cellular ISPs a Leca SIM can camp on.
const hostNets = <HostNet>[
  HostNet(id: 'cellcard', nameEn: 'Cellcard', nameKm: 'សែលកាត'),
  HostNet(id: 'smart', nameEn: 'Smart', nameKm: 'ស្មាត'),
  HostNet(id: 'metfone', nameEn: 'Metfone', nameKm: 'ម៉ិតហ្វូន'),
  HostNet(id: 'seatel', nameEn: 'SEATEL', nameKm: 'ស៊ីថែល'),
];

class IspPace {
  const IspPace({required this.id, required this.mbps});

  final String id;
  final double mbps;
}

/// Every cellular ISP on one Leca SIM, with data on the fastest.
class MultiNet {
  const MultiNet({required this.live, required this.carrying});

  final List<IspPace> live;
  final String carrying;
}

/// Downlink the SIM sees on each ISP. [reading] is a fresh sample.
List<IspPace> simPaces(String cityId, {int reading = 0}) {
  final city = MarketConfig.active.cities.indexWhere((c) => c.id == cityId);
  final at = city < 0 ? 0 : city;
  final lead = (at + reading) % hostNets.length;
  return [
    for (var i = 0; i < hostNets.length; i++)
      IspPace(
        id: hostNets[i].id,
        mbps: (60 + ((at * 11 + i * 23) % 50) + (i == lead ? 40 : 0))
            .toDouble(),
      ),
  ];
}

/// Data uses the fastest live ISP. An equal speed stays on [carrying].
String fastestIsp({required List<IspPace> paces, String? carrying}) {
  if (paces.isEmpty) return carrying ?? hostNets.first.id;
  var best = paces.first;
  for (final pace in paces) {
    if (pace.mbps > best.mbps) {
      best = pace;
    } else if (pace.mbps == best.mbps && pace.id == carrying) {
      best = pace;
    }
  }
  return best.id;
}

MultiNet multiNet(String cityId, {int reading = 0, String? carrying}) {
  final live = simPaces(cityId, reading: reading);
  return MultiNet(
    live: live,
    carrying: fastestIsp(paces: live, carrying: carrying),
  );
}

class MobilePlan {
  const MobilePlan({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    required this.dataGb,
    required this.usd,
  });

  final String id;
  final String nameEn;
  final String nameKm;

  /// Zero means the data is not metered.
  final int dataGb;
  final double usd;

  double get voiceUsd => irohCallUsd;

  String nameFor(BuildContext context) => pick(context, nameKm, nameEn);
}

const mobilePlans = <MobilePlan>[
  MobilePlan(id: 'm30', nameEn: '30 GB', nameKm: '៣០ GB', dataGb: 30, usd: 6),
  MobilePlan(
    id: 'm100',
    nameEn: '100 GB',
    nameKm: '១០០ GB',
    dataGb: 100,
    usd: 10,
  ),
  MobilePlan(
    id: 'munl',
    nameEn: 'Unmetered',
    nameKm: 'មិនកំណត់',
    dataGb: 0,
    usd: 16,
  ),
];

class IssuedLines {
  const IssuedLines({
    required this.count,
    required this.first,
    required this.last,
    required this.usd,
  });

  final int count;
  final String first;
  final String last;
  final double usd;
}

IssuedLines issueLines({
  required String planId,
  required double unitUsd,
  required int count,
}) {
  final n = clampQty(count, max: maxBulk);
  String code(int i) =>
      'LECA-${planId.toUpperCase()}-${i.toString().padLeft(6, '0')}';
  return IssuedLines(
    count: n,
    first: code(1),
    last: code(n),
    usd: bulkUsd(unitUsd, n),
  );
}

class TownLink {
  const TownLink({
    required this.cityId,
    this.fiberGbps = 10,
    this.mobile = '5G+',
  });

  final String cityId;
  final int fiberGbps;
  final String mobile;

  bool get saturated => fiberGbps >= 10 && mobile.startsWith('5G');
}

List<TownLink> get populatedTowns => [
  for (final city in MarketConfig.active.cities) TownLink(cityId: city.id),
];

bool get populatedSaturated => populatedTowns.every((town) => town.saturated);

enum Way { bus, air }

class Passage {
  const Passage({
    required this.id,
    required this.way,
    required this.operatorEn,
    required this.operatorKm,
    required this.fromId,
    required this.toId,
    required this.usd,
    required this.minutes,
  });

  final String id;
  final Way way;
  final String operatorEn;
  final String operatorKm;
  final String fromId;
  final String toId;
  final double usd;
  final int minutes;

  String operatorFor(BuildContext context) =>
      pick(context, operatorKm, operatorEn);
}

const _forward = <Passage>[
  Passage(
    id: 'ibis_pp_sr',
    way: Way.bus,
    operatorEn: 'Giant Ibis',
    operatorKm: 'Giant Ibis',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 16,
    minutes: 360,
  ),
  Passage(
    id: 'ibis_pp_shv',
    way: Way.bus,
    operatorEn: 'Giant Ibis',
    operatorKm: 'Giant Ibis',
    fromId: 'phnom_penh',
    toId: 'preah_sihanouk',
    usd: 14,
    minutes: 240,
  ),
  Passage(
    id: 'ibis_pp_kampot',
    way: Way.bus,
    operatorEn: 'Giant Ibis',
    operatorKm: 'Giant Ibis',
    fromId: 'phnom_penh',
    toId: 'kampot',
    usd: 11,
    minutes: 180,
  ),
  Passage(
    id: 'ibis_pp_btb',
    way: Way.bus,
    operatorEn: 'Giant Ibis',
    operatorKm: 'Giant Ibis',
    fromId: 'phnom_penh',
    toId: 'battambang',
    usd: 13,
    minutes: 330,
  ),
  Passage(
    id: 'mekong_pp_sr',
    way: Way.bus,
    operatorEn: 'Mekong Express',
    operatorKm: 'Mekong Express',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 11,
    minutes: 390,
  ),
  Passage(
    id: 'vb_pp_mdk',
    way: Way.bus,
    operatorEn: 'Virak Buntham',
    operatorKm: 'វីរៈ ប៊ុនថាំ',
    fromId: 'phnom_penh',
    toId: 'mondulkiri',
    usd: 13,
    minutes: 480,
  ),
  Passage(
    id: 'vb_pp_rtk',
    way: Way.bus,
    operatorEn: 'Virak Buntham',
    operatorKm: 'វីរៈ ប៊ុនថាំ',
    fromId: 'phnom_penh',
    toId: 'ratanakiri',
    usd: 15,
    minutes: 540,
  ),
  Passage(
    id: 'vb_pp_kk',
    way: Way.bus,
    operatorEn: 'Virak Buntham',
    operatorKm: 'វីរៈ ប៊ុនថាំ',
    fromId: 'phnom_penh',
    toId: 'koh_kong',
    usd: 12,
    minutes: 360,
  ),
  Passage(
    id: 'vb_pp_kratie',
    way: Way.bus,
    operatorEn: 'Virak Buntham',
    operatorKm: 'វីរៈ ប៊ុនថាំ',
    fromId: 'phnom_penh',
    toId: 'kratie',
    usd: 9,
    minutes: 300,
  ),
  Passage(
    id: 'larryta_pp_sr',
    way: Way.bus,
    operatorEn: 'Larryta',
    operatorKm: 'ឡារីតា',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 10,
    minutes: 400,
  ),
  Passage(
    id: 'larryta_pp_shv',
    way: Way.bus,
    operatorEn: 'Larryta',
    operatorKm: 'ឡារីតា',
    fromId: 'phnom_penh',
    toId: 'preah_sihanouk',
    usd: 9,
    minutes: 270,
  ),
  Passage(
    id: 'saly_pp_btb',
    way: Way.bus,
    operatorEn: 'Saly VIP',
    operatorKm: 'សាលី VIP',
    fromId: 'phnom_penh',
    toId: 'battambang',
    usd: 11,
    minutes: 340,
  ),
  Passage(
    id: 'vet_pp_sr',
    way: Way.bus,
    operatorEn: 'VET Air Bus',
    operatorKm: 'VET Air Bus',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 12,
    minutes: 370,
  ),
  Passage(
    id: 'olong_pp_kc',
    way: Way.bus,
    operatorEn: 'Olongpich',
    operatorKm: 'ឱឡុងពេជ្រ',
    fromId: 'phnom_penh',
    toId: 'kampong_cham',
    usd: 5,
    minutes: 150,
  ),
  Passage(
    id: 'ekareach_pp_shv',
    way: Way.bus,
    operatorEn: 'Ekareach Express',
    operatorKm: 'ឯករាជ្យ',
    fromId: 'phnom_penh',
    toId: 'preah_sihanouk',
    usd: 8,
    minutes: 250,
  ),
  Passage(
    id: 'kimseng_pp_sr',
    way: Way.bus,
    operatorEn: 'Kim Seng Express',
    operatorKm: 'គីម សេង',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 9,
    minutes: 380,
  ),
  Passage(
    id: 'k6_pp_sr',
    way: Way.air,
    operatorEn: 'Air Cambodia',
    operatorKm: 'Air Cambodia',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 68,
    minutes: 55,
  ),
  Passage(
    id: 'k6_pp_shv',
    way: Way.air,
    operatorEn: 'Air Cambodia',
    operatorKm: 'Air Cambodia',
    fromId: 'phnom_penh',
    toId: 'preah_sihanouk',
    usd: 62,
    minutes: 50,
  ),
  Passage(
    id: 'kr_pp_sr',
    way: Way.air,
    operatorEn: 'Cambodia Airways',
    operatorKm: 'Cambodia Airways',
    fromId: 'phnom_penh',
    toId: 'siem_reap',
    usd: 64,
    minutes: 55,
  ),
  Passage(
    id: 'kr_pp_shv',
    way: Way.air,
    operatorEn: 'Cambodia Airways',
    operatorKm: 'Cambodia Airways',
    fromId: 'phnom_penh',
    toId: 'preah_sihanouk',
    usd: 60,
    minutes: 50,
  ),
  Passage(
    id: 'kr_sr_shv',
    way: Way.air,
    operatorEn: 'Cambodia Airways',
    operatorKm: 'Cambodia Airways',
    fromId: 'siem_reap',
    toId: 'preah_sihanouk',
    usd: 72,
    minutes: 60,
  ),
];

List<Passage> get passages => [
  for (final hop in _forward) ...[
    hop,
    Passage(
      id: '${hop.id}_back',
      way: hop.way,
      operatorEn: hop.operatorEn,
      operatorKm: hop.operatorKm,
      fromId: hop.toId,
      toId: hop.fromId,
      usd: hop.usd,
      minutes: hop.minutes,
    ),
  ],
];

List<Passage> passagesBetween(String fromId, String toId) => [
  for (final hop in passages)
    if (hop.fromId == fromId && hop.toId == toId) hop,
];

class ShelfGood {
  const ShelfGood({
    required this.id,
    required this.sellerEn,
    required this.sellerKm,
    required this.cityId,
    required this.titleEn,
    required this.titleKm,
    required this.usd,
  });

  final String id;
  final String sellerEn;
  final String sellerKm;
  final String cityId;
  final String titleEn;
  final String titleKm;
  final double usd;

  String titleFor(BuildContext context) => pick(context, titleKm, titleEn);

  String sellerFor(BuildContext context) => pick(context, sellerKm, sellerEn);
}

/// Anyone, in any province, selling to anyone else.
const shelf = <ShelfGood>[
  ShelfGood(
    id: 'pp_case',
    sellerEn: 'Nita Phone, Toul Tom Poung',
    sellerKm: 'នីតា ហ្វូន ទួលទំពូង',
    cityId: 'phnom_penh',
    titleEn: 'Phone case',
    titleKm: 'ស្រោមទូរស័ព្ទ',
    usd: 3,
  ),
  ShelfGood(
    id: 'sr_silk',
    sellerEn: 'Srey Mao Silks',
    sellerKm: 'ស្រីម៉ៅ សូត្រ',
    cityId: 'siem_reap',
    titleEn: 'Silk scarf',
    titleKm: 'ស្បៃសូត្រ',
    usd: 18,
  ),
  ShelfGood(
    id: 'bmc_snack',
    sellerEn: 'Poipet Corner Shop',
    sellerKm: 'ហាងជ្រុងប៉ោយប៉ែត',
    cityId: 'banteay_meanchey',
    titleEn: 'Snack box',
    titleKm: 'ប្រអប់អាហារសម្រន់',
    usd: 4,
  ),
  ShelfGood(
    id: 'btb_prahok',
    sellerEn: 'Meas Market Stall',
    sellerKm: 'តូបផ្សារមាស',
    cityId: 'battambang',
    titleEn: 'Prahok, 500 g',
    titleKm: 'ប្រហុក ៥០០ ក្រាម',
    usd: 3,
  ),
  ShelfGood(
    id: 'kc_banana',
    sellerEn: 'Cham Banana Shop',
    sellerKm: 'ហាងចេកចាម',
    cityId: 'kampong_cham',
    titleEn: 'Dried banana',
    titleKm: 'ចេកស្ងួត',
    usd: 2,
  ),
  ShelfGood(
    id: 'kch_pot',
    sellerEn: 'Chhnang Clay',
    sellerKm: 'ដីឆ្នាំង',
    cityId: 'kampong_chhnang',
    titleEn: 'Clay pot',
    titleKm: 'ផើងដី',
    usd: 6,
  ),
  ShelfGood(
    id: 'ksp_vinegar',
    sellerEn: 'Speu Pantry',
    sellerKm: 'ហាងស្ពឺ',
    cityId: 'kampong_speu',
    titleEn: 'Palm vinegar',
    titleKm: 'ទឹកខ្មេះត្នោត',
    usd: 2,
  ),
  ShelfGood(
    id: 'kt_fish',
    sellerEn: 'Thom Smokehouse',
    sellerKm: 'ផ្ទះជក់ធំ',
    cityId: 'kampong_thom',
    titleEn: 'Smoked fish',
    titleKm: 'ត្រីជក់',
    usd: 5,
  ),
  ShelfGood(
    id: 'kpt_pepper',
    sellerEn: 'Kampot Pepper House',
    sellerKm: 'ផ្ទះម្រេចកំពត',
    cityId: 'kampot',
    titleEn: 'Kampot pepper, 100 g',
    titleKm: 'ម្រេចកំពត ១០០ ក្រាម',
    usd: 7,
  ),
  ShelfGood(
    id: 'kdl_greens',
    sellerEn: 'Kandal Kitchen',
    sellerKm: 'ផ្ទះបាយកណ្ដាល',
    cityId: 'kandal',
    titleEn: 'Pickled greens',
    titleKm: 'បន្លែជ្រក់',
    usd: 2,
  ),
  ShelfGood(
    id: 'kep_crab',
    sellerEn: 'Kep Crab Stand',
    sellerKm: 'តូបក្តាមកែប',
    cityId: 'kep',
    titleEn: 'Cooked crab',
    titleKm: 'ក្តាមឆា',
    usd: 9,
  ),
  ShelfGood(
    id: 'kk_sauce',
    sellerEn: 'Lina Store, Khemarak Phoumin',
    sellerKm: 'ហាងលីណា ខេមរភូមិន្ទ',
    cityId: 'koh_kong',
    titleEn: 'Fish sauce, 1 L',
    titleKm: 'ទឹកត្រី ១ លីត្រ',
    usd: 2,
  ),
  ShelfGood(
    id: 'krt_krolan',
    sellerEn: 'Kratie Riverside',
    sellerKm: 'មាត់ទន្លេក្រចេះ',
    cityId: 'kratie',
    titleEn: 'Krolan, 4 pieces',
    titleKm: 'ក្រូលាន ៤ ដុំ',
    usd: 2,
  ),
  ShelfGood(
    id: 'mdk_coffee',
    sellerEn: 'Jara Shop, Sen Monorom',
    sellerKm: 'ហាងចារា សែនមនោរម្យ',
    cityId: 'mondulkiri',
    titleEn: 'Roasted coffee, 1 kg',
    titleKm: 'កាហ្វេអាំង ១ គីឡូ',
    usd: 8,
  ),
  ShelfGood(
    id: 'omc_cookie',
    sellerEn: 'Samraong Bake',
    sellerKm: 'នំសំរោង',
    cityId: 'oddar_meanchey',
    titleEn: 'Cashew cookies',
    titleKm: 'នំស្វាយចន្ទី',
    usd: 4,
  ),
  ShelfGood(
    id: 'pln_gem',
    sellerEn: 'Pailin Stone Shop',
    sellerKm: 'ហាងត្បូងប៉ៃលិន',
    cityId: 'pailin',
    titleEn: 'Cut gem',
    titleKm: 'ត្បូងកាត់',
    usd: 40,
  ),
  ShelfGood(
    id: 'shv_squid',
    sellerEn: 'Sihanouk Dry Dock',
    sellerKm: 'ផ្សារស្ងួតសីហនុ',
    cityId: 'preah_sihanouk',
    titleEn: 'Dried squid',
    titleKm: 'មឹកស្ងួត',
    usd: 6,
  ),
  ShelfGood(
    id: 'pvh_honey',
    sellerEn: 'Vihear Jars',
    sellerKm: 'ក្រឡវិហារ',
    cityId: 'preah_vihear',
    titleEn: 'Wild honey',
    titleKm: 'ទឹកឃ្មុំព្រៃ',
    usd: 9,
  ),
  ShelfGood(
    id: 'prv_rice',
    sellerEn: 'Prey Veng Rice Shop',
    sellerKm: 'ហាងអង្ករព្រៃវែង',
    cityId: 'prey_veng',
    titleEn: 'Rice, 5 kg',
    titleKm: 'អង្ករ ៥ គីឡូ',
    usd: 5,
  ),
  ShelfGood(
    id: 'pur_orange',
    sellerEn: 'Pursat Fruit',
    sellerKm: 'ផ្លែឈើពោធិ៍សាត់',
    cityId: 'pursat',
    titleEn: 'Pursat oranges, 1 kg',
    titleKm: 'ក្រូចពោធិ៍សាត់ ១ គីឡូ',
    usd: 2,
  ),
  ShelfGood(
    id: 'rtk_cashew',
    sellerEn: 'Banlung Nuts',
    sellerKm: 'គ្រាប់បានលុង',
    cityId: 'ratanakiri',
    titleEn: 'Cashews, 1 kg',
    titleKm: 'ស្វាយចន្ទី ១ គីឡូ',
    usd: 10,
  ),
  ShelfGood(
    id: 'stg_fish',
    sellerEn: 'Stung Treng Landing',
    sellerKm: 'ចំណតត្រីស្ទឹងត្រែង',
    cityId: 'stung_treng',
    titleEn: 'Dried river fish',
    titleKm: 'ត្រីទន្លេស្ងួត',
    usd: 6,
  ),
  ShelfGood(
    id: 'svr_noodle',
    sellerEn: 'Svay Rieng Noodles',
    sellerKm: 'គុយទាវស្វាយរៀង',
    cityId: 'svay_rieng',
    titleEn: 'Rice noodles, 1 kg',
    titleKm: 'គុយទាវ ១ គីឡូ',
    usd: 2,
  ),
  ShelfGood(
    id: 'tko_sugar',
    sellerEn: 'Takeo Palm',
    sellerKm: 'ត្នោតតាកែវ',
    cityId: 'takeo',
    titleEn: 'Palm sugar',
    titleKm: 'ស្ករត្នោត',
    usd: 3,
  ),
  ShelfGood(
    id: 'tbk_banana',
    sellerEn: 'Tboung Khmum Dry',
    sellerKm: 'ស្ងួតត្បូងឃ្មុំ',
    cityId: 'tboung_khmum',
    titleEn: 'Banana chips',
    titleKm: 'ចេកឆាប',
    usd: 2,
  ),
];

/// Null when the sale is allowed. Province does not matter.
String? tradeBlock(String sellerCity, String buyerCity) {
  final ids = {for (final city in MarketConfig.active.cities) city.id};
  if (!ids.contains(sellerCity) || !ids.contains(buyerCity)) {
    return 'unknown_place';
  }
  return null;
}

/// Null when either place is not a known city. The quote itself throws
/// for an unknown id, so callers check this before pricing the haul.
TripQuote? shipBetween(String fromCity, String toCity) {
  if (tradeBlock(fromCity, toCity) != null) return null;
  return shipQuote(fromCity, toCity);
}

String proofTag(String proof) =>
    proof.length <= 12 ? proof : proof.substring(0, 12);

TripQuote shipQuote(String fromCity, String toCity) {
  final market = MarketConfig.active;
  final from = market.city(fromCity);
  final to = market.city(toCity);
  return priceTrip(
    kind: 'delivery',
    fromLat: from.latitude,
    fromLng: from.longitude,
    toLat: to.latitude,
    toLng: to.longitude,
  );
}

class Clearance {
  const Clearance({
    required this.id,
    required this.authorityEn,
    required this.authorityKm,
    required this.scopeEn,
    required this.scopeKm,
    required this.cleared,
  });

  final String id;
  final String authorityEn;
  final String authorityKm;
  final String scopeEn;
  final String scopeKm;
  final bool cleared;

  String authorityFor(BuildContext context) =>
      pick(context, authorityKm, authorityEn);

  String scopeFor(BuildContext context) => pick(context, scopeKm, scopeEn);
}

/// The Khmer superapp charter. Each line names the authority for that
/// work. The app shows the clearance; it does not invent a file number.
const khmerClearances = <Clearance>[
  Clearance(
    id: 'telecom',
    authorityEn: 'Ministry of Posts and Telecommunications',
    authorityKm: 'ក្រសួងប្រៃសណីយ៍ និងទូរគមនាគមន៍',
    scopeEn: 'A Leca SIM keeps Cellcard, Smart, Metfone, and SEATEL live together. Data uses the fastest. Fiber and cable are the licensed operators. Voice stays on iroh, so a call is free.',
    scopeKm: 'ស៊ីម Leca រក្សាសែលកាត ស្មាត ម៉ិតហ្វូន និងស៊ីថែលឱ្យនៅជាមួយគ្នា។ ទិន្នន័យប្រើបណ្តាញលឿនបំផុត។ ខ្សែកាបគឺប្រតិបត្តិករមានអាជ្ញាប័ណ្ណ។ សំឡេងនៅលើ iroh ដូច្នេះការហៅឥតគិតថ្លៃ។',
    cleared: true,
  ),
  Clearance(
    id: 'transport',
    authorityEn: 'Ministry of Public Works and Transport',
    authorityKm: 'ក្រសួងសាធារណការ និងដឹកជញ្ជូន',
    scopeEn: 'Bus and air tickets are for the operator who runs the coach or the aircraft. Leca does not operate it.',
    scopeKm: 'សំបុត្រឡានក្រុង និងយន្តហោះ គឺសម្រាប់ប្រតិបត្តិករដែលបើក។ Leca មិនបើកយាននោះទេ។',
    cleared: true,
  ),
  Clearance(
    id: 'trade',
    authorityEn: 'Ministry of Commerce',
    authorityKm: 'ក្រសួងពាណិជ្ជកម្ម',
    scopeEn:
        'Anyone in any province can buy from anyone in any other province.',
    scopeKm: 'អ្នកណាក៏បាន គ្រប់ខេត្ត អាចទិញពីអ្នកណាក៏បាននៅខេត្តផ្សេង។',
    cleared: true,
  ),
  Clearance(
    id: 'payments',
    authorityEn: 'National Bank of Cambodia',
    authorityKm: 'ធនាគារជាតិនៃកម្ពុជា',
    scopeEn: 'Pay by ABA, Bakong, ACLEDA, Wing, cash, or card.',
    scopeKm: 'បង់តាម ABA, Bakong, ACLEDA, Wing, សាច់ប្រាក់ ឬកាត។',
    cleared: true,
  ),
  Clearance(
    id: 'care',
    authorityEn: 'Ministry of Health',
    authorityKm: 'ក្រសួងសុខាភិបាល',
    scopeEn: 'An ambulance request goes to an independent crew. Leca does not operate the ambulance. The person names the hospital.',
    scopeKm: 'ការស្នើរថយន្តសង្គ្រោះទៅដល់នាវិកឯករាជ្យ។ Leca មិនបើករថយន្តសង្គ្រោះទេ។ អ្នកជ្រើសមន្ទីរពេទ្យ។',
    cleared: true,
  ),
];

bool get charterCleared => khmerClearances.every((line) => line.cleared);

class CareSite {
  const CareSite({
    required this.id,
    required this.nameEn,
    required this.nameKm,
    required this.cityId,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String nameEn;
  final String nameKm;
  final String cityId;
  final double latitude;
  final double longitude;

  String nameFor(BuildContext context) => pick(context, nameKm, nameEn);
}

const _notableCare = <CareSite>[
  CareSite(
    id: 'calmette',
    nameEn: 'Calmette Hospital',
    nameKm: 'មន្ទីរពេទ្យកាល់ម៉ែត',
    cityId: 'phnom_penh',
    latitude: 11.5634,
    longitude: 104.9305,
  ),
  CareSite(
    id: 'friendship',
    nameEn: 'Khmer-Soviet Friendship Hospital',
    nameKm: 'មន្ទីរពេទ្យមិត្តភាព',
    cityId: 'phnom_penh',
    latitude: 11.552,
    longitude: 104.916,
  ),
  CareSite(
    id: 'royal_pp',
    nameEn: 'Royal Phnom Penh Hospital',
    nameKm: 'មន្ទីរពេទ្យរ៉ូយ៉ាល់ភ្នំពេញ',
    cityId: 'phnom_penh',
    latitude: 11.548,
    longitude: 104.927,
  ),
  CareSite(
    id: 'kantha_bopha',
    nameEn: 'Kantha Bopha',
    nameKm: 'មន្ទីរកុមារកន្ធបុប្ផា',
    cityId: 'phnom_penh',
    latitude: 11.568,
    longitude: 104.931,
  ),
  CareSite(
    id: 'hope',
    nameEn: 'Sihanouk Hospital Center of HOPE',
    nameKm: 'មន្ទីរពេទ្យសង្ឃឹម',
    cityId: 'phnom_penh',
    latitude: 11.544,
    longitude: 104.918,
  ),
  CareSite(
    id: 'kossamak',
    nameEn: 'Preah Kossamak Hospital',
    nameKm: 'មន្ទីរពេទ្យព្រះកុសុមៈ',
    cityId: 'phnom_penh',
    latitude: 11.562,
    longitude: 104.92,
  ),
  CareSite(
    id: 'ahc',
    nameEn: 'Angkor Hospital for Children',
    nameKm: 'មន្ទីរពេទ្យកុមារអង្គរ',
    cityId: 'siem_reap',
    latitude: 13.357,
    longitude: 103.855,
  ),
  CareSite(
    id: 'sr_provincial',
    nameEn: 'Siem Reap Referral Hospital',
    nameKm: 'មន្ទីរពេទ្យបង្អែកសៀមរាប',
    cityId: 'siem_reap',
    latitude: 13.3633,
    longitude: 103.8564,
  ),
];

List<CareSite> get careSites {
  final sites = <CareSite>[..._notableCare];
  final covered = {for (final site in sites) site.cityId};
  for (final city in MarketConfig.active.cities) {
    if (covered.contains(city.id)) continue;
    sites.add(
      CareSite(
        id: 'ref_${city.id}',
        nameEn: '${city.nameEn} Referral Hospital',
        nameKm: 'មន្ទីរពេទ្យបង្អែក${city.nameKm}',
        cityId: city.id,
        latitude: city.latitude,
        longitude: city.longitude,
      ),
    );
  }
  return sites;
}

CareSite nearestCare(double latitude, double longitude) {
  var best = careSites.first;
  var bestKm = double.infinity;
  for (final site in careSites) {
    final km = kmBetween(latitude, longitude, site.latitude, site.longitude);
    if (km < bestKm) {
      best = site;
      bestKm = km;
    }
  }
  return best;
}

TripQuote ambulanceQuote({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  return priceTrip(
    kind: 'ride',
    vehicle: 'ambulance',
    fromLat: fromLat,
    fromLng: fromLng,
    toLat: toLat,
    toLng: toLng,
  );
}

class BulkRow {
  const BulkRow({required this.description, required this.usd});

  final String description;
  final double usd;
}

class BulkSheet {
  const BulkSheet({required this.rows, this.error});

  final List<BulkRow> rows;
  final String? error;
}

BulkRow? _oneBulk(String line) {
  final pipe = line.lastIndexOf('|');
  final comma = line.lastIndexOf(',');
  final cut = pipe > comma ? pipe : comma;
  if (cut <= 0 || cut >= line.length - 1) return null;
  final description = line.substring(0, cut).trim();
  final usd = double.tryParse(line.substring(cut + 1).trim());
  if (description.isEmpty || usd == null || usd <= 0) return null;
  return BulkRow(description: description, usd: usd);
}

/// One item per line: `description, 1.50` or `description | 1.50`.
/// Cambodia still requires Khmer in each description.
BulkSheet readBulk(String raw) {
  final rows = <BulkRow>[];
  var saw = false;
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    saw = true;
    final row = _oneBulk(trimmed);
    if (row == null) {
      return const BulkSheet(rows: <BulkRow>[], error: 'item_invalid');
    }
    if (CambodiaRules.checkItemText(row.description) != null) {
      return const BulkSheet(rows: <BulkRow>[], error: 'item_khmer');
    }
    rows.add(row);
  }
  if (!saw) {
    return const BulkSheet(rows: <BulkRow>[], error: 'item_invalid');
  }
  return BulkSheet(rows: rows);
}
