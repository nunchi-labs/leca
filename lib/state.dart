import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'auth.dart';
import 'auth_api.dart';
import 'catalog.dart';
import 'compliance.dart';
import 'geo.dart';
import 'quote.dart';
import 'talk.dart';
import 'identity.dart';
import 'location.dart';
import 'market.dart';
import 'rate.dart';
import 'records.dart';
import 'traffic.dart';
import 'vault.dart';

class LecaState extends ChangeNotifier {
  LecaState({Vault? vault})
    : vault = vault ?? MemoryVault(),
      locale = MarketConfig.active.defaultLocale,
      cityId = MarketConfig.active.defaultCityId,
      railId = MarketConfig.active.defaultRailId;

  /// Everything below that matters survives a restart through here.
  final Vault vault;
  Timer? _saveTimer;
  bool _restoring = false;
  bool restored = false;

  Locale locale;
  String cityId;
  String railId;

  /// Kilometres from [origin]. [countryWide] means the whole country, not a circle.
  double radiusKm = 10;
  TripFix? here;

  static const countryWide = 101.0;

  bool get wholeCountry => radiusKm >= countryWide;
  PopularWindow window = PopularWindow.hour;
  String note = '';
  Booking? booking;
  final Map<String, int> qty = <String, int>{};

  Session? session;
  bool authLoading = false;
  String? authError;
  String? pendingPhone;
  bool phoneCodeSent = false;
  String? devCode;
  final Map<String, String> _emailPasswords = {};

  final List<BusinessListing> businesses = <BusinessListing>[];
  final List<ShopItem> items = <ShopItem>[];
  final List<ChatMessage> messages = <ChatMessage>[];
  final Map<String, List<int>> replySamples = <String, List<int>>{};
  final List<ListedVehicle> vehicles = <ListedVehicle>[];
  DriverProfile? driver;
  String? driverError;

  /// Every bargain in the app, by fare key. One place, so a kitchen chat,
  /// a booking card, and checkout all see the same price.
  final Map<String, FareAsk> fareAsks = <String, FareAsk>{};
  RidePartner? rideMatch;
  final Set<String> suspendedPartnerIds = <String>{};
  final List<TripShare> shares = <TripShare>[];
  final List<PlatformReport> reports = <PlatformReport>[];
  bool driving = false;
  String driveNote = '';
  String? supplyError;
  bool supplyLoading = false;

  final List<OperatorJob> jobs = <OperatorJob>[];
  bool jobsLoading = false;
  String? jobsError;

  LocaleCode get lang =>
      locale.languageCode == 'km' ? LocaleCode.km : LocaleCode.en;

  /// Saves shortly after every change. Writes are coalesced so a burst of
  /// taps costs one write.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (_restoring) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), save);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    try {
      await vault.write(jsonEncode(toJson()));
    } catch (_) {}
  }

  /// Loads the last saved state. Safe to call on an empty or damaged vault.
  Future<void> restore() async {
    String? raw;
    try {
      raw = await vault.read();
    } catch (_) {}
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _restoring = true;
          try {
            _apply(decoded);
          } finally {
            _restoring = false;
          }
        }
      } catch (_) {}
    }
    restored = true;
    super.notifyListeners();
    unawaited(_refreshRateCard());
    unawaited(refreshTrust());
  }

  /// Prices follow the card the server publishes. The last one seen is
  /// kept, so the app prices on it offline too.
  Future<void> _refreshRateCard() async {
    final card = await fetchRateCard();
    if (card == null || card.id == RateCard.active.id) return;
    RateCard.adopt(card);
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'rateCard': RateCard.active.toJson(),
    'locale': locale.languageCode,
    'cityId': cityId,
    'railId': railId,
    'radiusKm': radiusKm,
    'note': note,
    'booking': booking?.toJson(),
    'qty': qty,
    'session': session?.toJson(),
    'businesses': [for (final b in businesses) b.toJson()],
    'items': [for (final i in items) i.toJson()],
    'messages': [for (final m in messages) m.toJson()],
    'replySamples': replySamples,
    'vehicles': [for (final v in vehicles) v.toJson()],
    'driver': driver?.toJson(),
    'fareAsks': {
      for (final entry in fareAsks.entries) entry.key: entry.value.toJson(),
    },
    'suspendedPartnerIds': suspendedPartnerIds.toList(),
    'reports': [for (final r in reports) r.toJson()],
    'driving': driving,
    'driveNote': driveNote,
  };

  void _apply(Map<dynamic, dynamic> raw) {
    final card = RateCard.fromJson(raw['rateCard']);
    if (card != null) RateCard.adopt(card);
    final lang = '${raw['locale'] ?? ''}';
    if (lang == 'km' || lang == 'en') locale = Locale(lang);
    final market = MarketConfig.active;
    final city = '${raw['cityId'] ?? ''}';
    if (market.cities.any((c) => c.id == city)) cityId = city;
    final rail = '${raw['railId'] ?? ''}';
    if (market.rails.any((r) => r.id == rail)) railId = rail;
    final radius = raw['radiusKm'];
    if (radius is num) radiusKm = radius.toDouble().clamp(1, countryWide);
    note = '${raw['note'] ?? ''}';
    booking = Booking.fromJson(raw['booking']);
    final rawQty = raw['qty'];
    if (rawQty is Map) {
      qty
        ..clear()
        ..addAll({
          for (final entry in rawQty.entries)
            if (entry.value is num && (entry.value as num) > 0)
              '${entry.key}': (entry.value as num).toInt(),
        });
    }
    session = Session.fromJson(raw['session']);
    _fill(raw['businesses'], businesses, BusinessListing.fromJson);
    _fill(raw['items'], items, ShopItem.fromJson);
    _fill(raw['messages'], messages, ChatMessage.fromJson);
    final samples = raw['replySamples'];
    if (samples is Map) {
      replySamples
        ..clear()
        ..addAll({
          for (final entry in samples.entries)
            if (entry.value is List)
              '${entry.key}': [
                for (final n in entry.value as List)
                  if (n is num) n.toInt(),
              ],
        });
    }
    _fill(raw['vehicles'], vehicles, ListedVehicle.fromJson);
    driver = DriverProfile.fromJson(raw['driver']);
    final asks = raw['fareAsks'];
    if (asks is Map) {
      fareAsks.clear();
      for (final entry in asks.entries) {
        final ask = FareAsk.fromJson(entry.value);
        if (ask != null) fareAsks['${entry.key}'] = ask;
      }
    }
    final suspended = raw['suspendedPartnerIds'];
    if (suspended is List) {
      suspendedPartnerIds
        ..clear()
        ..addAll([for (final id in suspended) '$id']);
    }
    _fill(raw['reports'], reports, PlatformReport.fromJson);
    driving = raw['driving'] == true;
    driveNote = '${raw['driveNote'] ?? ''}';
    syncRideMatch(notify: false);
  }

  static void _fill<T>(Object? raw, List<T> into, T? Function(Object?) parse) {
    if (raw is! List) return;
    into.clear();
    for (final item in raw) {
      final parsed = parse(item);
      if (parsed != null) into.add(parsed);
    }
  }

  City get city => MarketConfig.active.city(cityId);

  /// Device fix, or Phnom Penh until the phone provides one.
  TripFix get origin =>
      here ?? const TripFix(latitude: 11.5564, longitude: 104.9282);

  bool covers(double latitude, double longitude) {
    if (wholeCountry) return true;
    return kmBetween(origin.latitude, origin.longitude, latitude, longitude) <=
        radiusKm;
  }

  void setRadius(double km) {
    final next = km.clamp(1, countryWide).toDouble();
    if ((next - radiusKm).abs() < 0.01) return;
    radiusKm = next;
    notifyListeners();
  }

  Future<void> loadHere() async {
    final fix = await TripLocation.current();
    if (fix == null) return;
    here = fix;
    cityId = _nearestCity(fix).id;
    notifyListeners();
  }

  /// A computer has no GPS. The delivery point is the city they pick.
  void deliverToCity(String id) {
    final place = MarketConfig.active.city(id);
    cityId = place.id;
    here = TripFix(latitude: place.latitude, longitude: place.longitude);
    notifyListeners();
  }

  City _nearestCity(TripFix fix) {
    var best = MarketConfig.active.cities.first;
    var bestKm = double.infinity;
    for (final place in MarketConfig.active.cities) {
      final km = kmBetween(
        fix.latitude,
        fix.longitude,
        place.latitude,
        place.longitude,
      );
      if (km < bestKm) {
        best = place;
        bestKm = km;
      }
    }
    return best;
  }

  PaymentRail get rail => MarketConfig.active.railById(railId);

  bool get signedIn => session != null;

  Kitchen? get cartKitchen {
    for (final kitchen in Catalog.kitchens) {
      for (final dish in kitchen.menu) {
        if ((qty[dish.id] ?? 0) > 0) return kitchen;
      }
    }
    return null;
  }

  int get itemCount => qty.values.fold(0, (a, b) => a + b);

  bool get hasPayable => itemCount > 0 || booking != null;

  String get payableLabel {
    if (itemCount > 0) return cartKitchen?.nameEn ?? MarketConfig.brand;
    return booking?.title ?? MarketConfig.brand;
  }

  double get subtotalUsd {
    var sum = 0.0;
    for (final kitchen in Catalog.kitchens) {
      for (final dish in kitchen.menu) {
        final n = qty[dish.id] ?? 0;
        if (n > 0) sum += dish.usd * n;
      }
    }
    return sum;
  }

  String deliveryFareKey(Kitchen kitchen) {
    final quote = deliveryQuoteOf(kitchen);
    return 'delivery:${kitchen.id}:${quote.meters}:${quote.minutes}';
  }

  TripQuote deliveryQuoteOf(Kitchen kitchen) {
    return priceTrip(
      kind: 'delivery',
      fromLat: kitchen.latitude,
      fromLng: kitchen.longitude,
      toLat: origin.latitude,
      toLng: origin.longitude,
    );
  }

  double get deliveryUsd {
    final kitchen = cartKitchen;
    if (kitchen == null) return 0;
    final quote = deliveryQuoteOf(kitchen);
    return payable(deliveryFareKey(kitchen), quote.usd);
  }

  /// Price before Leca's fee. Food includes its delivery charge.
  double get saleUsd {
    if (itemCount > 0) return subtotalUsd + deliveryUsd;
    return booking?.amountUsd ?? 0;
  }

  double get feeUsd => saleFeeUsd(saleUsd);

  double get totalUsd {
    final cents = (saleUsd * 100).round() + (feeUsd * 100).round();
    return cents / 100;
  }

  void toggleLocale() {
    locale = locale.languageCode == 'km'
        ? const Locale('en')
        : const Locale('km');
    notifyListeners();
  }

  void setCity(String id) {
    if (cityId == id) return;
    cityId = id;
    notifyListeners();
  }

  void setWindow(PopularWindow value) {
    window = value;
    notifyListeners();
  }

  void setRail(String id) {
    railId = id;
    notifyListeners();
  }

  void setNote(String value) {
    note = value;
    notifyListeners();
  }

  void addDish(Dish dish, Kitchen kitchen) {
    booking = null;
    final current = cartKitchen;
    if (current != null && current.id != kitchen.id) {
      qty.clear();
    }
    qty[dish.id] = (qty[dish.id] ?? 0) + 1;
    notifyListeners();
  }

  void removeDish(Dish dish) {
    final n = (qty[dish.id] ?? 0) - 1;
    if (n <= 0) {
      qty.remove(dish.id);
    } else {
      qty[dish.id] = n;
    }
    notifyListeners();
  }

  int countOf(String dishId) => qty[dishId] ?? 0;

  void setBooking(Booking value) {
    qty.clear();
    booking = value;
    rideMatch = null;
    notifyListeners();
  }

  void clearCart() {
    qty.clear();
    booking = null;
    rideMatch = null;
    note = '';
    railId = MarketConfig.active.defaultRailId;
    notifyListeners();
  }

  void syncRideMatch({bool notify = true}) {
    final current = booking;
    RidePartner? next;
    if (current != null &&
        current.kind == BookKind.ride &&
        CambodiaRules.applies()) {
      final kind = current.vehicleId.isEmpty
          ? current.title
          : current.vehicleId;
      next = CambodiaRules.match(
        vehicleKind: kind,
        suspended: suspendedPartnerIds,
        driver: driver,
      );
    }
    if (next?.id == rideMatch?.id && next?.plate == rideMatch?.plate) return;
    rideMatch = next;
    if (notify) notifyListeners();
  }

  Future<String> shareTrip(String audience) async {
    final fix = await TripLocation.current();
    final at = DateTime.now().toUtc();
    final text = CambodiaRules.shareText(
      partner: rideMatch,
      cityName: city.nameEn,
      at: at,
      audience: audience,
      latitude: fix?.latitude,
      longitude: fix?.longitude,
    );
    shares.add(
      TripShare(
        audience: audience,
        text: text,
        at: at,
        hasLocation: fix != null,
      ),
    );
    notifyListeners();
    return text;
  }

  Future<void> fileSafetyReport(String category) async {
    const allowed = {'intoxication', 'violence', 'harassment'};
    if (!allowed.contains(category)) return;
    final partner = rideMatch;
    if (partner == null) return;
    var id = 'r_${reports.length + 1}';
    var status = 'suspended';
    if (AuthConfig.apiLive && (session?.token ?? '').isNotEmpty) {
      try {
        final posted = await AuthApi.post('/v1/report', {
          'category': category,
          'subjectId': partner.id,
        }, token: session!.token);
        id = '${posted['id'] ?? id}';
        status = '${posted['status'] ?? status}';
      } catch (_) {
        return;
      }
    }
    suspendedPartnerIds.add(partner.id);
    final local = driver;
    if (local != null && local.staffId == partner.id) {
      driver = local.copyWith(suspended: true);
      driving = false;
    }
    reports.add(
      PlatformReport(
        id: id,
        kind: 'safety',
        category: category,
        subjectId: partner.id,
        status: status,
      ),
    );
    rideMatch = CambodiaRules.match(
      vehicleKind: partner.vehicleKind,
      suspended: suspendedPartnerIds,
      driver: driver,
    );
    notifyListeners();
  }

  /// The named partner answers a report. A person then upholds or clears it.
  Future<String?> appealReport(String id, String note) async {
    final text = note.trim();
    if (text.isEmpty) return 'appeal_empty';
    final i = reports.indexWhere((r) => r.id == id);
    if (i < 0) return 'report_unknown';
    if (AuthConfig.apiLive && (session?.token ?? '').isNotEmpty) {
      try {
        await AuthApi.post('/v1/report/appeal', {
          'id': id,
          'note': text,
        }, token: session!.token);
      } on AuthApiException catch (e) {
        return e.code;
      } catch (_) {
        return 'failed';
      }
    }
    reports[i] = reports[i].copyWith(status: 'appealed', appeal: text);
    notifyListeners();
    return null;
  }

  List<PlatformReport> get openPartnerReports {
    final staffId = driver?.staffId ?? '';
    if (staffId.isEmpty) return const [];
    return [
      for (final report in reports)
        if (report.subjectId == staffId &&
            (report.status == 'suspended' || report.status == 'appealed'))
          report,
    ];
  }

  Future<void> refreshTrust() async {
    if (!AuthConfig.apiLive) return;
    try {
      final listed = await AuthApi.get('/v1/suspended');
      final ids = listed['staffIds'];
      if (ids is List) {
        suspendedPartnerIds
          ..clear()
          ..addAll([for (final id in ids) '$id']);
      }
    } catch (_) {}
    final token = session?.token;
    if (token != null && token.isNotEmpty) {
      try {
        final status = await AuthApi.get('/v1/driver/status', token: token);
        final review = '${status['review'] ?? ''}';
        if (driver != null && review.isNotEmpty && review != 'none') {
          driver = driver!.copyWith(
            review: review,
            reviewNote: '${status['note'] ?? ''}',
            suspended: status['suspended'] == true,
          );
          if (driver!.suspended) driving = false;
        }
        final mine = status['reports'];
        if (mine is List) {
          for (final item in mine) {
            final parsed = PlatformReport.fromJson(item);
            if (parsed == null) continue;
            final i = reports.indexWhere((r) => r.id == parsed.id);
            if (i < 0) {
              reports.add(parsed);
            } else {
              reports[i] = parsed;
            }
          }
        }
      } catch (_) {}
    }
    syncRideMatch(notify: false);
    notifyListeners();
  }

  void fileConsumerReport(String businessId, String note) {
    if (businessId.trim().isEmpty) return;
    reports.add(
      PlatformReport(
        id: 'r_${reports.length + 1}',
        kind: 'consumer',
        category: 'complaint',
        subjectId: businessId,
        status: 'recorded',
        note: note.trim(),
      ),
    );
    notifyListeners();
  }

  void takeDownItem(String itemId) {
    final i = items.indexWhere((item) => item.id == itemId);
    if (i < 0 || items[i].removed) return;
    items[i] = items[i].takeDown();
    reports.add(
      PlatformReport(
        id: 'r_${reports.length + 1}',
        kind: 'takedown',
        category: 'listing',
        subjectId: itemId,
        status: 'removed',
      ),
    );
    notifyListeners();
  }

  Future<void> signIn({
    required String method,
    required String handle,
    String? code,
    String? password,
    String? name,
    bool register = false,
  }) async {
    authError = null;
    authLoading = true;
    notifyListeners();
    if (AuthConfig.apiLive) {
      try {
        await _liveSignIn(
          method: method,
          handle: handle,
          code: code,
          password: password,
          name: name,
          register: register,
        );
      } on AuthException catch (e) {
        authError = e.code;
      } on AuthApiException catch (e) {
        authError = e.code;
      } catch (_) {
        authError = 'failed';
      }
      authLoading = false;
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 380));
    try {
      if (method == 'email') {
        _mockEmail(
          email: handle,
          password: password ?? '',
          name: name ?? '',
          register: register,
        );
        pendingPhone = null;
        phoneCodeSent = false;
        authLoading = false;
        notifyListeners();
        return;
      }
      if (method == 'whatsapp' || method == 'phone') {
        final digits = handle.replaceAll(RegExp(r'\D'), '');
        if (digits.length < 8) {
          throw const AuthException('phone_invalid');
        }
        if (!phoneCodeSent) {
          pendingPhone = handle;
          phoneCodeSent = true;
          authLoading = false;
          notifyListeners();
          return;
        }
        if (code == null || code.length < 4) {
          throw const AuthException('code_invalid');
        }
      }
      if (handle.trim().isEmpty) {
        throw const AuthException('handle_empty');
      }
      session = Session(
        id: 'u_${DateTime.now().toUtc().millisecondsSinceEpoch}',
        method: method,
        displayName: method == 'whatsapp' || method == 'phone'
            ? handle
            : handle.split('@').first,
        handle: handle,
      );
      pendingPhone = null;
      phoneCodeSent = false;
    } on AuthException catch (e) {
      authError = e.code;
    } catch (_) {
      authError = 'failed';
    }
    authLoading = false;
    notifyListeners();
  }

  Future<void> _liveSignIn({
    required String method,
    required String handle,
    String? code,
    String? password,
    String? name,
    bool register = false,
  }) async {
    if (method == 'email') {
      final path = register
          ? '/v1/auth/email/register'
          : '/v1/auth/email/login';
      _takeSession(
        await AuthApi.post(path, {
          'email': handle,
          'password': password ?? '',
          'name': name ?? '',
        }),
      );
      return;
    }
    if (method == 'whatsapp' || method == 'phone') {
      final digits = handle.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8) throw const AuthException('phone_invalid');
      if (!phoneCodeSent) {
        final started = await AuthApi.post('/v1/auth/whatsapp/start', {
          'phone': handle,
        });
        pendingPhone = handle;
        phoneCodeSent = true;
        devCode = started['devCode'] as String?;
        return;
      }
      if (code == null || code.trim().length < 4) {
        throw const AuthException('code_invalid');
      }
      _takeSession(
        await AuthApi.post('/v1/auth/whatsapp/verify', {
          'phone': handle,
          'code': code.trim(),
        }),
      );
      return;
    }
    _takeSession(await AuthApi.finishProvider(method));
  }

  void _mockEmail({
    required String email,
    required String password,
    required String name,
    required bool register,
  }) {
    final address = email.trim().toLowerCase();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address);
    if (!ok) throw const AuthException('email_invalid');
    if (password.length < 8) throw const AuthException('password_short');
    if (register) {
      if (_emailPasswords.containsKey(address)) {
        throw const AuthException('email_taken');
      }
      _emailPasswords[address] = password;
    } else if (_emailPasswords[address] != password) {
      throw const AuthException('credentials_invalid');
    }
    final display = name.trim().isEmpty
        ? address.split('@').first
        : name.trim();
    session = Session(
      id: 'email:$address',
      method: 'email',
      displayName: display,
      handle: address,
    );
  }

  void _takeSession(Map<String, Object?> json) {
    final user = json['user'];
    if (user is! Map) throw const AuthException('failed');
    session = Session(
      id: '${user['id']}',
      method: '${user['method']}',
      displayName: '${user['displayName']}',
      handle: '${user['handle']}',
      token: '${json['token'] ?? ''}',
    );
    pendingPhone = null;
    phoneCodeSent = false;
    devCode = null;
  }

  void signOut() {
    session = null;
    businesses.clear();
    items.clear();
    messages.clear();
    replySamples.clear();
    vehicles.clear();
    driver = null;
    driverError = null;
    fareAsks.clear();
    rideMatch = null;
    suspendedPartnerIds.clear();
    shares.clear();
    reports.clear();
    driving = false;
    driveNote = '';
    jobs.clear();
    jobsError = null;
    jobsLoading = false;
    phoneCodeSent = false;
    pendingPhone = null;
    devCode = null;
    authError = null;
    clearCart();
    notifyListeners();
  }

  Future<void> openBusiness({
    required String kind,
    required String name,
    String note = '',
    String sellerName = '',
    String sellerPhone = '',
    String sellerId = '',
  }) async {
    supplyError = null;
    supplyLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (kind.trim().isEmpty || name.trim().isEmpty) {
      supplyError = 'business_invalid';
      supplyLoading = false;
      notifyListeners();
      return;
    }
    final seller = CambodiaRules.checkSeller(
      sellerName: sellerName,
      sellerPhone: sellerPhone,
      sellerId: sellerId,
    );
    if (seller != null) {
      supplyError = seller;
      supplyLoading = false;
      notifyListeners();
      return;
    }
    businesses.add(
      BusinessListing(
        id: 'b_${businesses.length + 1}',
        kind: kind.trim(),
        name: name.trim(),
        cityId: cityId,
        note: note.trim(),
        sellerName: sellerName.trim(),
        sellerPhone: sellerPhone.trim(),
        sellerId: sellerId.trim(),
        latitude: origin.latitude,
        longitude: origin.longitude,
      ),
    );
    supplyLoading = false;
    notifyListeners();
  }

  Future<void> listVehicle({
    required String kind,
    required bool withDriver,
    required bool autonomous,
    String note = '',
    bool owner = false,
  }) async {
    supplyError = null;
    supplyLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (kind.trim().isEmpty) {
      supplyError = 'vehicle_invalid';
      supplyLoading = false;
      notifyListeners();
      return;
    }
    if (CambodiaRules.rejectsPlatformFleet(autonomous)) {
      supplyError = 'platform_fleet';
      supplyLoading = false;
      notifyListeners();
      return;
    }
    if (CambodiaRules.applies() && !owner) {
      supplyError = 'owner_required';
      supplyLoading = false;
      notifyListeners();
      return;
    }
    vehicles.add(
      ListedVehicle(
        id: 'v_${vehicles.length + 1}',
        kind: kind.trim(),
        withDriver: withDriver,
        autonomous: autonomous,
        note: note.trim(),
        owner: owner,
        latitude: origin.latitude,
        longitude: origin.longitude,
      ),
    );
    supplyLoading = false;
    notifyListeners();
  }

  String? setDriving({required bool value, String note = ''}) {
    if (value) {
      final block = CambodiaRules.onlineBlock(driver);
      if (block != null) {
        driving = false;
        driverError = block;
        driveNote = note;
        notifyListeners();
        return block;
      }
    }
    driverError = null;
    driving = value;
    driveNote = note;
    notifyListeners();
    if (value) {
      loadJobs();
    }
    return null;
  }

  List<OperatorJob> get openJobs =>
      jobs.where((j) => j.status == 'open').toList();

  List<OperatorJob> get nearbyOpenJobs =>
      openJobs.where((job) => covers(job.latitude, job.longitude)).toList();

  List<OperatorJob> get acceptedJobs =>
      jobs.where((j) => j.status == 'accepted').toList();

  Future<void> loadJobs({bool fail = false}) async {
    if (!driving) {
      jobsError = 'jobs_offline';
      notifyListeners();
      return;
    }
    jobsError = null;
    jobsLoading = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (fail) {
      jobsError = 'jobs_failed';
      jobsLoading = false;
      notifyListeners();
      return;
    }
    if (jobs.isEmpty) {
      jobs.addAll(_exampleJobs(origin, city));
    }
    jobsLoading = false;
    notifyListeners();
  }

  void acceptJob(String id) {
    final i = jobs.indexWhere((j) => j.id == id);
    if (i < 0) return;
    jobs[i] = jobs[i].copyWith(status: 'accepted');
    notifyListeners();
  }

  void declineJob(String id) {
    final i = jobs.indexWhere((j) => j.id == id);
    if (i < 0) return;
    jobs[i] = jobs[i].copyWith(status: 'declined');
    notifyListeners();
  }

  static List<OperatorJob> _exampleJobs(TripFix origin, City city) {
    TripFix at(double kmNorth) => northOf(origin, kmNorth);
    OperatorJob job({
      required String id,
      required String kind,
      required String titleKm,
      required String titleEn,
      required double kmNorth,
      String room = '',
    }) {
      final point = at(kmNorth);
      final quote = priceTrip(
        kind: kind == 'ride' ? 'ride' : 'delivery',
        vehicle: kind == 'ride' ? 'tuktuk' : '',
        fromLat: origin.latitude,
        fromLng: origin.longitude,
        toLat: point.latitude,
        toLng: point.longitude,
      );
      return OperatorJob(
        id: id,
        kind: kind,
        titleKm: titleKm,
        titleEn: titleEn,
        detailKm: city.nameKm,
        detailEn: city.nameEn,
        usd: quote.usd,
        latitude: point.latitude,
        longitude: point.longitude,
        room: room,
      );
    }

    return [
      job(
        id: 'j_food',
        kind: 'food',
        titleKm: 'ដឹកនំបញ្ចុក',
        titleEn: 'Deliver nom banh chok',
        kmNorth: 1.2,
        room: 'nom_banh_chok',
      ),
      job(
        id: 'j_ride',
        kind: 'ride',
        titleKm: 'ជិះទូកទូក',
        titleEn: 'Tuktuk ride',
        kmNorth: 3,
      ),
      job(
        id: 'j_send',
        kind: 'send',
        titleKm: 'ផ្ញើកញ្ចប់',
        titleEn: 'Send a parcel',
        kmNorth: 8,
      ),
    ];
  }

  void clearSupplyError() {
    if (supplyError == null && !supplyLoading) return;
    supplyError = null;
    supplyLoading = false;
    notifyListeners();
  }

  Future<String?> registerDriver({
    required String legalName,
    required String nameOnId,
    required String idNumber,
    required String phone,
    required String vehicleKind,
    required Uint8List? selfie,
    required Uint8List? idCard,
    Uint8List? licencePhoto,
    Uint8List? registrationPhoto,
    Uint8List? insurancePhoto,
    String licenceNumber = '',
    String plate = '',
    String registration = '',
    String inspection = '',
    String domesticCert = '',
    String insurance = '',
    bool logoOnVehicle = false,
    bool independentPartner = false,
    bool trainedTrafficLaw = false,
    bool trainedDriving = false,
    bool trainedService = false,
    bool trainedConduct = false,
  }) async {
    driverError = null;
    if (vehicleKind.trim().isEmpty) {
      driverError = 'vehicle_invalid';
      notifyListeners();
      return driverError;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) {
      driverError = 'phone_invalid';
      notifyListeners();
      return driverError;
    }
    final extras = CambodiaRules.needsMotorFile(vehicleKind)
        ? [licencePhoto, registrationPhoto, insurancePhoto]
        : const <Uint8List?>[];
    final code = await Identity.check(
      legalName: legalName,
      nameOnId: nameOnId,
      idNumber: idNumber,
      selfie: selfie,
      idCard: idCard,
      extras: extras,
    );
    if (code != null) {
      driverError = code;
      notifyListeners();
      return code;
    }
    final partner = CambodiaRules.checkPartner(
      vehicleKind: vehicleKind,
      licenceNumber: licenceNumber,
      plate: plate,
      registration: registration,
      inspection: inspection,
      domesticCert: domesticCert,
      insurance: insurance,
      logoOnVehicle: logoOnVehicle,
      independentPartner: independentPartner,
      trainedTrafficLaw: trainedTrafficLaw,
      trainedDriving: trainedDriving,
      trainedService: trainedService,
      trainedConduct: trainedConduct,
    );
    if (partner != null) {
      driverError = partner;
      notifyListeners();
      return partner;
    }
    final staffId = CambodiaRules.staffIdFor(idNumber);
    var review = 'local';
    var reviewNote = '';
    if (AuthConfig.apiLive && (session?.token ?? '').isNotEmpty) {
      try {
        final posted = await AuthApi.post('/v1/driver/file', {
          'staffId': staffId,
          'vehicleKind': vehicleKind.trim(),
          'legalName': legalName.trim(),
          'phone': phone.trim(),
          'licenceNumber': licenceNumber.trim(),
          'plate': plate.trim(),
          'registration': registration.trim(),
          'inspection': inspection.trim(),
          'domesticCert': domesticCert.trim(),
          'insurance': insurance.trim(),
          'selfie': base64Encode(selfie!),
          'idCard': base64Encode(idCard!),
          if (licencePhoto != null) 'licencePhoto': base64Encode(licencePhoto),
          if (registrationPhoto != null)
            'registrationPhoto': base64Encode(registrationPhoto),
          if (insurancePhoto != null)
            'insurancePhoto': base64Encode(insurancePhoto),
        }, token: session!.token);
        review = '${posted['review'] ?? 'pending'}';
        reviewNote = '${posted['note'] ?? ''}';
      } catch (_) {
        review = 'pending';
      }
    }
    driver = DriverProfile(
      legalName: legalName.trim(),
      nameOnId: nameOnId.trim(),
      idNumber: idNumber.trim(),
      phone: phone.trim(),
      vehicleKind: vehicleKind.trim(),
      selfie: selfie!,
      idCard: idCard!,
      licenceNumber: licenceNumber.trim(),
      plate: plate.trim(),
      registration: registration.trim(),
      inspection: inspection.trim(),
      domesticCert: domesticCert.trim(),
      insurance: insurance.trim(),
      logoOnVehicle: logoOnVehicle,
      independentPartner: independentPartner || !CambodiaRules.applies(),
      trained:
          trainedTrafficLaw &&
          trainedDriving &&
          trainedService &&
          trainedConduct,
      staffId: staffId,
      suspended: suspendedPartnerIds.contains(staffId),
      licencePhoto: licencePhoto,
      registrationPhoto: registrationPhoto,
      insurancePhoto: insurancePhoto,
      review: review,
      reviewNote: reviewNote,
    );
    notifyListeners();
    return null;
  }

  void clearDriverError() {
    if (driverError == null) return;
    driverError = null;
    notifyListeners();
  }

  String? addItem({
    required String businessId,
    required String description,
    required double usd,
    required Uint8List? photo,
  }) {
    if (description.trim().isEmpty ||
        usd <= 0 ||
        photo == null ||
        photo.isEmpty) {
      return 'item_invalid';
    }
    final khmer = CambodiaRules.checkItemText(description);
    if (khmer != null) return khmer;
    items.add(
      ShopItem(
        id: 'item_${items.length + 1}',
        businessId: businessId,
        description: description.trim(),
        usd: usd,
        photo: photo,
      ),
    );
    notifyListeners();
    return null;
  }

  List<ShopItem> itemsFor(String businessId) => items
      .where((item) => item.businessId == businessId && !item.removed)
      .toList();

  List<ChatMessage> thread(String placeId) =>
      messages.where((message) => message.placeId == placeId).toList();

  bool owns(String placeId) => businesses.any((b) => b.id == placeId);

  (int, int) hoursFor(String placeId) {
    for (final business in businesses) {
      if (business.id == placeId) {
        return (business.openHour, business.closeHour);
      }
    }
    for (final kitchen in Catalog.kitchens) {
      if (kitchen.id == placeId) {
        return (kitchen.openHour, kitchen.closeHour);
      }
    }
    return (defaultOpenHour, defaultCloseHour);
  }

  int? replySecondsFor(String placeId) {
    final live = averageSeconds(replySamples[placeId] ?? const <int>[]);
    if (live != null) return live;
    for (final kitchen in Catalog.kitchens) {
      if (kitchen.id == placeId) return kitchen.typicalReplySeconds;
    }
    return null;
  }

  void sendMessage({
    required String placeId,
    required String text,
    required bool asBusiness,
    DateTime? at,
    String kind = 'text',
    String? name,
  }) {
    final body = text.trim();
    if (body.isEmpty) return;
    final now = at ?? DateTime.now();
    if (kind == 'text' && asBusiness) {
      final asked = _pendingCustomer(placeId);
      if (asked != null) {
        final hours = hoursFor(placeId);
        final delay = inHoursDelay(
          asked: asked.at,
          replied: now,
          openHour: hours.$1,
          closeHour: hours.$2,
        );
        if (delay != null) {
          replySamples.putIfAbsent(placeId, () => <int>[]).add(delay);
        }
      }
    }
    final line = talkAppend(
      prior: _chain(placeId),
      room: placeId,
      kind: kind,
      name: name ?? (asBusiness ? 'Shop' : session?.displayName ?? 'Guest'),
      who: name == null && !asBusiness ? who : '',
      at: now,
      text: body,
    );
    if (line.text.isEmpty) return;
    messages.add(
      ChatMessage(
        id: 'm_${messages.length + 1}',
        placeId: placeId,
        text: line.text,
        asBusiness: asBusiness,
        at: now,
        kind: line.kind,
        name: line.name,
        who: line.who,
        seq: line.seq,
        prev: line.prev,
        proof: line.proof,
        stamp: line.at,
      ),
    );
    notifyListeners();
  }

  /// This account's handle inside a room. Empty before sign-in.
  String get who => talkWho(session?.id ?? '');

  List<TalkLine> _chain(String placeId) => [
    for (final message in thread(placeId))
      if (message.proof.isNotEmpty)
        TalkLine(
          seq: message.seq,
          room: placeId,
          kind: message.kind,
          name: message.name,
          who: message.who,
          at: message.stamp,
          text: message.text,
          prev: message.prev,
          proof: message.proof,
        ),
  ];

  bool talkOk(String placeId) => talkChecks(_chain(placeId));

  void appendTalk(TalkLine line) {
    if (!line.checksOut) return;
    final prior = _chain(line.room);
    if (prior.any((message) => message.seq == line.seq)) return;
    final prev = prior.isEmpty ? '' : prior.last.proof;
    if (line.prev != prev || line.seq != prior.length + 1) return;
    messages.add(
      ChatMessage(
        id: 'm_${messages.length + 1}',
        placeId: line.room,
        text: line.text,
        asBusiness: false,
        at: DateTime.tryParse(line.at)?.toLocal() ?? DateTime.now(),
        kind: line.kind,
        name: line.name,
        who: line.who,
        seq: line.seq,
        prev: line.prev,
        proof: line.proof,
        stamp: line.at,
      ),
    );
    notifyListeners();
  }

  ChatMessage? _pendingCustomer(String placeId) {
    ChatMessage? customer;
    for (final message in messages) {
      if (message.placeId != placeId) continue;
      if (message.asBusiness) {
        customer = null;
      } else {
        customer = message;
      }
    }
    return customer;
  }

  /// The bargain over one fare, if anyone has bid on it.
  FareAsk? askFor(String key) => fareAsks[key];

  /// Either side may name a price, as often as they like. The price in
  /// force does not move until the other side allows a bid.
  void proposeFare(
    String key,
    double appUsd,
    double askUsd, {
    String proposer = 'driver',
  }) {
    if (askUsd <= 0) return;
    final usd = (askUsd * 100).round() / 100;
    final side = proposer == 'customer' ? 'customer' : 'driver';
    final current = fareAsks[key] ?? FareAsk(key: key, appUsd: appUsd);
    fareAsks[key] = current.bid(usd, side);
    notifyListeners();
  }

  /// Who this device speaks for when it proposes a price.
  String get fareSide => driving ? 'driver' : 'customer';

  void allowFare(String key) {
    final ask = fareAsks[key];
    if (ask == null || !ask.open) return;
    fareAsks[key] = ask.allow();
    notifyListeners();
  }

  /// Closes the bargain. The agreed price, or the app price, stands.
  void endFare(String key) {
    final ask = fareAsks[key];
    if (ask == null) return;
    fareAsks[key] = ask.end();
    notifyListeners();
  }

  double payable(String key, double appUsd) {
    final ask = fareAsks[key];
    return ask?.agreedUsd ?? appUsd;
  }

  double listedPrice(ListedVehicle vehicle, {required bool sale}) {
    final kind = vehicle.kind.toLowerCase();
    for (final offer in MarketConfig.active.exampleVehicles) {
      if (offer.id == kind || offer.nameEn.toLowerCase() == kind) {
        return sale ? offer.salePrice : offer.rentPrice;
      }
    }
    return sale ? 100 : 6;
  }

  String newOrderId() {
    final now = DateTime.now().toUtc();
    final stamp =
        '${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'LECA$stamp';
  }
}

class AuthException implements Exception {
  const AuthException(this.code);
  final String code;
}

class LecaScope extends InheritedNotifier<LecaState> {
  const LecaScope({
    super.key,
    required LecaState super.notifier,
    required super.child,
  });

  static LecaState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LecaScope>();
    assert(scope != null, 'LecaScope missing');
    return scope!.notifier!;
  }
}
