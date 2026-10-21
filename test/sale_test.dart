import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/auth.dart';
import 'package:leca/l10n/app_localizations.dart';
import 'package:leca/market.dart';
import 'package:leca/sale.dart';
import 'package:leca/state.dart';

void main() {
  test('a Honda ADV 350 lists as a motorcycle at the named price', () {
    final state = LecaState();
    expect(
      state.listSale(
        kind: 'motorcycle',
        title: 'Honda ADV 350',
        note: 'ម៉ូតូ',
        usd: double.nan,
        owner: true,
        sellerName: 'Dara',
        sellerPhone: '012345678',
        sellerId: '123456789',
      ),
      'sale_invalid',
    );
    expect(
      state.listSale(
        kind: 'bicycle',
        title: 'Honda ADV 350',
        note: 'ម៉ូតូ Honda ADV 350',
        usd: 4200,
        owner: true,
        sellerName: 'Dara',
        sellerPhone: '012345678',
        sellerId: '123456789',
      ),
      'sale_kind',
    );
    expect(
      state.listSale(
        kind: 'motorcycle',
        title: 'Honda ADV 350',
        note: 'Honda ADV 350',
        usd: 4200,
        owner: true,
        sellerName: 'Dara',
        sellerPhone: '012345678',
        sellerId: '123456789',
      ),
      'item_khmer',
    );
    expect(
      state.listSale(
        kind: 'moto',
        title: 'Honda ADV 350',
        note: 'ម៉ូតូ Honda ADV 350 ស្ថានភាពល្អ',
        usd: 4200,
        owner: true,
        sellerName: 'Dara',
        sellerPhone: '012345678',
        sellerId: '123456789',
      ),
      isNull,
    );
    expect(state.sales, hasLength(1));
    final sale = state.sales.single;
    expect(sale.kind, 'motorcycle');
    expect(sale.title, 'Honda ADV 350');
    expect(sale.usd, 4200);
    final restored = VehicleSale.fromJson(sale.toJson());
    expect(restored?.title, 'Honda ADV 350');
    expect(restored?.kind, 'motorcycle');

    state.signOut();
    expect(state.sales, isEmpty);
  });

  testWidgets('the sales page lists a Honda ADV 350 and opens checkout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final state = LecaState();
    await tester.pumpWidget(
      LecaScope(
        notifier: state,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VehicleSaleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing for sale in this radius.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_sale_form')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale_example_adv')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('sale_note')),
      'ម៉ូតូ Honda ADV 350 ស្ថានភាពល្អ',
    );
    await tester.enterText(find.byKey(const Key('sale_price')), '4200');
    await tester.enterText(find.byKey(const Key('sale_seller_name')), 'Dara');
    await tester.enterText(
      find.byKey(const Key('sale_seller_phone')),
      '012345678',
    );
    await tester.enterText(
      find.byKey(const Key('sale_seller_id')),
      '123456789',
    );
    await tester.tap(find.byKey(const Key('sale_owner')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save_sale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_sale')));
    await tester.pumpAndSettle();

    expect(find.text('Honda ADV 350'), findsOneWidget);
    expect(find.textContaining(r'$4200.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sale_filter_car')));
    await tester.pump();
    expect(find.text('Honda ADV 350'), findsNothing);

    await tester.tap(find.byKey(const Key('sale_filter_motorcycle')));
    await tester.pump();
    expect(find.text('Honda ADV 350'), findsOneWidget);

    await tester.tap(find.byKey(Key('buy_${state.sales.single.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Honda ADV 350'), findsWidgets);
    expect(find.textContaining('Service fee'), findsOneWidget);
    expect(state.booking?.kind, BookKind.goods);
    expect(state.booking?.amountUsd, 4200);
  });
}
