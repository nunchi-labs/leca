import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/apart.dart';
import 'package:leca/l10n/app_localizations.dart';
import 'package:leca/map_screen.dart';
import 'package:leca/market.dart';
import 'package:leca/state.dart';
import 'package:leca/traffic.dart';
import 'package:leca/vault.dart';

void main() {
  test(
    'Phnom Penh to Siem Reap is a straight line, a longer walk, and a drive',
    () {
      const pp = (lat: 11.5564, lng: 104.9282);
      const sr = (lat: 13.3633, lng: 103.8564);
      final gap = gapBetween(pp.lat, pp.lng, sr.lat, sr.lng);
      expect(gap.crow.meters, inInclusiveRange(210000, 260000));
      expect(gap.walk.meters, greaterThan(gap.crow.meters));
      expect(gap.drive.meters, greaterThan(gap.walk.meters));
      expect(gap.crow.minutes, 0);
      expect(gap.walk.minutes, greaterThan(gap.drive.minutes));
      expect(gap.walk.routed, isFalse);
      expect(gap.drive.routed, isFalse);
    },
  );

  test('two people in the same place have no gap', () {
    final gap = gapBetween(11.55, 104.92, 11.55, 104.9201);
    expect(gap.crow.meters, 0);
    expect(gap.walk.meters, 0);
    expect(gap.drive.meters, 0);
  });

  test(
    'a live route replaces the walk and the drive, not the straight line',
    () {
      final estimate = gapBetween(11.55, 104.92, 11.57, 104.94);
      final live = gapWithRoutes(estimate, walk: null, drive: null);
      expect(live.drive.meters, estimate.drive.meters);
      const walked = RoadRoute(minutes: 40, meters: 2800);
      const driven = RoadRoute(minutes: 12, meters: 3100);
      final routed = gapWithRoutes(estimate, walk: walked, drive: driven);
      expect(routed.crow.meters, estimate.crow.meters);
      expect(routed.crow.routed, isFalse);
      expect(routed.walk.meters, 2800);
      expect(routed.walk.minutes, 40);
      expect(routed.walk.routed, isTrue);
      expect(routed.drive.meters, 3100);
      expect(routed.drive.routed, isTrue);
    },
  );

  test('the chart keeps both pins inside the frame', () {
    final frame = mapFrame(11.55, 104.92, 13.36, 103.85);
    expect(frame.south, lessThan(11.55));
    expect(frame.north, greaterThan(13.36));
    expect(frame.west, lessThan(103.85));
    expect(frame.east, greaterThan(104.92));
    expect(frame.widthKm, greaterThan(0));
    expect(gapDistance(850), '850 m');
    expect(gapDistance(2400), '2.4 km');
    expect(gapDistance(232000), '232 km');
  });

  testWidgets('the map shows the three distances', (tester) async {
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
          home: MapScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('As the crow flies'), findsOneWidget);
    expect(find.text('Walking'), findsOneWidget);
    expect(find.text('Driving'), findsOneWidget);
    expect(find.textContaining('km'), findsWidgets);
    expect(MarketConfig.active.city('siem_reap').nameEn, 'Siem Reap');
  });
}
