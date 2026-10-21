import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/l10n/app_localizations.dart';
import 'package:leca/market.dart';
import 'package:leca/qty.dart';
import 'package:leca/rate_card.dart';
import 'package:leca/reach.dart';
import 'package:leca/reach_screen.dart';
import 'package:leca/state.dart';
import 'package:leca/vault.dart';

void main() {
  test('licensed fiber and cable are dozens of 10 Gbps lines', () {
    expect(fiberPlans.length, greaterThanOrEqualTo(40));
    expect(
      fiberPlans.map((plan) => plan.id).toSet(),
      hasLength(fiberPlans.length),
    );
    for (final plan in fiberPlans) {
      expect(plan.gbps, 10, reason: plan.id);
      expect(plan.usd, greaterThan(0));
    }
    expect(fiberPlans.where((plan) => plan.medium == Medium.cable), isNotEmpty);
    expect(fiberPlans.where((plan) => plan.medium == Medium.fiber), isNotEmpty);
    expect(fiberPlans.any((plan) => plan.id == 'ezecom'), isTrue);
    expect(fiberPlans.any((plan) => plan.id == 'sinet'), isTrue);
  });

  test('every populated center is on 10 Gbps and 5G+', () {
    expect(populatedTowns, hasLength(MarketConfig.active.cities.length));
    expect(populatedSaturated, isTrue);
    for (final town in populatedTowns) {
      expect(town.fiberGbps, 10);
      expect(town.mobile, '5G+');
    }
    expect(homeHotspots.every((spot) => spot.mobile == '5G+'), isTrue);
  });

  test('an MVNO line is free to call and can be issued in bulk', () {
    expect(irohCallUsd, 0);
    expect(userComms, 'iroh');
    expect(hostNets, hasLength(4));
    expect(mobilePlans.every((plan) => plan.voiceUsd == 0), isTrue);
    final net = multiNet('phnom_penh');
    expect(
      net.live.map((pace) => pace.id).toSet(),
      hostNets.map((host) => host.id).toSet(),
    );
    expect(net.carrying, fastestIsp(paces: net.live, carrying: null));
    expect(
      fastestIsp(
        paces: const [
          IspPace(id: 'cellcard', mbps: 40),
          IspPace(id: 'smart', mbps: 90),
          IspPace(id: 'metfone', mbps: 55),
          IspPace(id: 'seatel', mbps: 70),
        ],
        carrying: null,
      ),
      'smart',
    );
    expect(
      fastestIsp(
        paces: const [
          IspPace(id: 'smart', mbps: 90),
          IspPace(id: 'cellcard', mbps: 97),
        ],
        carrying: 'smart',
      ),
      'cellcard',
    );
    expect(
      fastestIsp(
        paces: const [
          IspPace(id: 'smart', mbps: 100),
          IspPace(id: 'seatel', mbps: 100),
        ],
        carrying: 'seatel',
      ),
      'seatel',
    );
    final moved = multiNet('phnom_penh', reading: 1, carrying: net.carrying);
    expect(moved.carrying, isNot(net.carrying));
    expect(moved.live, hasLength(hostNets.length));
    final issued = issueLines(planId: 'm30', unitUsd: 6, count: 3);
    expect(issued.first, 'LECA-M30-000001');
    expect(issued.last, 'LECA-M30-000003');
    expect(issued.usd, 18);
    final huge = issueLines(planId: 'm30', unitUsd: 6, count: 5000000);
    expect(huge.count, maxBulk);
    expect(huge.usd, bulkUsd(6, maxBulk));
  });

  test('bus and air tickets run in both directions', () {
    final go = passagesBetween('phnom_penh', 'siem_reap');
    final back = passagesBetween('siem_reap', 'phnom_penh');
    expect(go.where((hop) => hop.way == Way.bus), isNotEmpty);
    expect(go.where((hop) => hop.way == Way.air), isNotEmpty);
    expect(back, hasLength(go.length));
    final ids = {for (final city in MarketConfig.active.cities) city.id};
    for (final hop in passages) {
      expect(ids.contains(hop.fromId), isTrue, reason: hop.id);
      expect(ids.contains(hop.toId), isTrue, reason: hop.id);
    }
  });

  test('anyone can buy from the other end of the country', () {
    final ids = {for (final city in MarketConfig.active.cities) city.id};
    expect(shelf.map((good) => good.cityId).toSet(), containsAll(ids));
    for (final good in shelf) {
      expect(tradeBlock(good.cityId, 'koh_kong'), isNull, reason: good.id);
    }
    expect(tradeBlock('mondulkiri', 'koh_kong'), isNull);
    expect(tradeBlock('nowhere', 'kep'), 'unknown_place');
    expect(shipBetween('nowhere', 'kep'), isNull);
    expect(shipBetween('mondulkiri', 'koh_kong')?.checksOut, isTrue);
    expect(proofTag(''), '');
    expect(proofTag('abcdefghijklmnop'), 'abcdefghijkl');
    final coffee = shelf.firstWhere((good) => good.cityId == 'mondulkiri');
    final ship = shipQuote(coffee.cityId, 'koh_kong');
    expect(ship.checksOut, isTrue);
    expect(haulCount(1), 1);
    expect(haulCount(21), 2);
    expect(haulCount(1000), 50);
    final landed = landedUsd(unit: coffee.usd, count: 1000, shipOnce: ship.usd);
    expect(landed, bulkUsd(coffee.usd, 1000) + bulkUsd(ship.usd, 50));
  });

  test('bulk lines need Khmer and a price', () {
    final ok = readBulk('ភួយ, 4.50\nកាហ្វេ | 8');
    expect(ok.error, isNull);
    expect(ok.rows, hasLength(2));
    expect(ok.rows.first.usd, 4.5);
    expect(readBulk('pillow, 4').error, 'item_khmer');
    expect(readBulk('ភួយ').error, 'item_invalid');
    expect(clampQty(0, max: maxAmbulances), 1);
    expect(clampQty(40, max: maxAmbulances), maxAmbulances);
    expect(bulkUsd(1.25, 4), 5);
  });

  test('the Khmer charter is cleared, including emergency care', () {
    expect(charterCleared, isTrue);
    expect(
      khmerClearances.map((line) => line.id),
      containsAll(['telecom', 'transport', 'trade', 'payments', 'care']),
    );
    expect(khmerClearances.every((line) => line.cleared), isTrue);
  });

  test('an ambulance is priced to the nearest hospital', () {
    final site = nearestCare(11.5564, 104.9282);
    expect(site.id, 'calmette');
    final cities = {for (final city in MarketConfig.active.cities) city.id};
    expect(careSites.map((item) => item.cityId).toSet(), containsAll(cities));
    final quote = ambulanceQuote(
      fromLat: 11.5564,
      fromLng: 104.9282,
      toLat: site.latitude,
      toLng: site.longitude,
    );
    expect(quote.checksOut, isTrue);
    expect(quote.vehicle, 'ambulance');
    expect(RateCard.active.scale('ambulance'), 220);
  });

  testWidgets('the charter and an ambulance request are on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final state = LecaState(vault: MemoryVault());
    addTearDown(state.dispose);
    await tester.pumpWidget(
      LecaScope(
        notifier: state,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CharterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('charter_status')), findsOneWidget);
    expect(find.text('Cleared'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Ministry of Health'), 200);
    expect(find.text('Ministry of Health'), findsOneWidget);

    await tester.pumpWidget(
      LecaScope(
        notifier: state,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CareScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Calmette'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('send_ambulance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send_ambulance')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(state.booking?.vehicleId, 'ambulance');
    expect(state.booking?.kind, BookKind.ride);
    expect(state.booking?.proof, isNotEmpty);
  });

  testWidgets('a quantity past the cap is what gets charged', (tester) async {
    var charged = 1;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QtyBar(max: maxAmbulances, onChanged: (n) => charged = n),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('qty_field')), '10');
    await tester.pump();
    expect(charged, 10);

    await tester.enterText(find.byKey(const Key('qty_field')), '0');
    await tester.pump();
    expect(charged, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('qty_field')))
          .controller
          ?.text,
      '1',
    );

    await tester.enterText(find.byKey(const Key('qty_field')), '40');
    await tester.pump();
    expect(charged, maxAmbulances);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('qty_field')))
          .controller
          ?.text,
      '12',
    );
  });
}
