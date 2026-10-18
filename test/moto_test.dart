import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/book.dart';
import 'package:leca/l10n/app_localizations.dart';
import 'package:leca/market.dart';
import 'package:leca/state.dart';

void main() {
  testWidgets('a motorcycle with no trailer is its own ride', (tester) async {
    final state = LecaState();
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      LecaScope(
        notifier: state,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const BookScreen(kind: BookKind.ride, vehicleId: 'motorcycle'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Motorcycle'), findsWidgets);
    expect(find.textContaining('no trailer'), findsOneWidget);
    expect(
      find.textContaining('Phnom Penh and across Cambodia'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'based in Siem Reap, where Grab does not offer a motorcycle',
      ),
      findsOneWidget,
    );
    expect(find.text('Tuktuk'), findsNothing);
    expect(find.byKey(const Key('ride_offer_motorcycle')), findsOneWidget);
    expect(find.byKey(const Key('other_rides')), findsOneWidget);

    await tester.tap(find.byKey(const Key('other_rides')));
    await tester.pumpAndSettle();
    expect(
      find.text('No trailer. The passenger sits behind the driver.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ride_offer_tuktuk')), findsOneWidget);
  });
}
