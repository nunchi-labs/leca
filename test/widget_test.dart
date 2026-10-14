import 'package:leca/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _run(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _signInGoogle(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const LecaApp());
  await tester.pump();
  expect(find.byKey(const Key('sign_in_phone')), findsOneWidget);
  await tester.tap(find.byKey(const Key('sign_in_more')));
  await tester.pump();
  expect(find.byKey(const Key('sign_in_google')), findsOneWidget);
  await tester.tap(find.byKey(const Key('sign_in_google')));
  await tester.pump();
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

void main() {
  testWidgets('mock Google sign-in then Khmer home and rides within radius', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _signInGoogle(tester);

      expect(find.text('Leca'), findsWidgets);
      expect(find.text('អាហារ'), findsOneWidget);
      expect(find.text('ជិះ'), findsOneWidget);
      expect(find.text('ជួលយាន'), findsOneWidget);
      expect(find.text('ផ្ញើអ្វីក៏បាន'), findsOneWidget);
      expect(find.text('នំបញ្ចុកព្រឹក'), findsOneWidget);
      expect(find.textContaining('គ្រប់ក្រុង ឃុំ និងភូមិ'), findsWidgets);
      expect(find.byKey(const Key('search_radius')), findsOneWidget);
      expect(find.text('ម្ហូបខ្មែរអង្គរ'), findsNothing);

      await tester.tap(find.text('ជិះ'));
      await tester.pumpAndSettle();
      expect(find.text('ទូកទូក'), findsOneWidget);
      expect(find.text('រម៉ក'), findsWidgets);
      await tester.tap(find.text('បញ្ជាទិញ').first);
      await tester.pumpAndSettle();
      expect(find.text('ABA Pay'), findsOneWidget);
      expect(find.text('Visa'), findsOneWidget);
      expect(find.text('Mastercard'), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('UnionPay'), findsWidgets);
      expect(find.text('Alipay'), findsWidgets);
      expect(find.text('ACLEDA'), findsOneWidget);
      expect(find.text('សាច់ប្រាក់'), findsOneWidget);
      expect(find.text('ដារ៉ា កែម'), findsOneWidget);
      expect(find.textContaining('2A-4521'), findsOneWidget);
    });
  });

  testWidgets(
    'a rental quotes the route, and the kitchen chat carries a price',
    (tester) async {
      await _run(TargetPlatform.android, () async {
        await _signInGoogle(tester);

        await tester.tap(find.text('ជួលយាន'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dropoff')), findsOneWidget);
        expect(find.byKey(const Key('rent_hours_24')), findsOneWidget);
        expect(find.byKey(const Key('fare_proof_rent:car')), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'fare_propose_rent:car:driver:',
                ),
            skipOffstage: false,
          ),
          findsOneWidget,
        );
        expect(find.byType(SwitchListTile), findsWidgets);
        Navigator.of(tester.element(find.byKey(const Key('dropoff')))).pop();
        await tester.pumpAndSettle();

        await tester.tap(find.text('នំបញ្ចុកព្រឹក'));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('talk_price')), findsOneWidget);
        expect(find.byKey(const Key('send_chat')), findsOneWidget);
      });
    },
  );

  testWidgets('phone mock rejects short numbers then signs in', (tester) async {
    await _run(TargetPlatform.android, () async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const LecaApp());
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('sign_in_phone_number')),
        '123',
      );
      await tester.tap(find.byKey(const Key('sign_in_phone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('បញ្ចូលលេខទូរស័ព្ទយ៉ាងតិច ៨ ខ្ទង់។'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('sign_in_phone_number')),
        '012345678',
      );
      await tester.tap(find.byKey(const Key('sign_in_phone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byKey(const Key('sign_in_phone_code')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('sign_in_phone_code')), '12');
      await tester.tap(find.byKey(const Key('sign_in_phone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('លេខកូដមិនត្រឹមត្រូវ។'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('sign_in_phone_code')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('sign_in_phone')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(const Key('account_button')), findsOneWidget);
    });
  });

  testWidgets(
    'operator opens a shop, stays offline without a partner file, and lists an owned vehicle',
    (tester) async {
      await _run(TargetPlatform.android, () async {
        await _signInGoogle(tester);
        await tester.tap(find.byKey(const Key('account_button')));
        await tester.pumpAndSettle();
        expect(find.text('មិនទាន់មានអាជីវកម្ម។'), findsOneWidget);
        expect(find.text('មិនទាន់មានយានដាក់។'), findsOneWidget);

        await tester.tap(find.byKey(const Key('open_business')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('pharmacy'));
        await tester.pump();
        await tester.enterText(find.byType(TextField).at(1), 'សុខា ឱសថស្ថាន');
        await tester.enterText(find.byType(TextField).at(2), 'Sokha Meas');
        await tester.enterText(find.byType(TextField).at(3), '012345678');
        await tester.enterText(find.byType(TextField).at(4), '123456789');
        await tester.tap(find.byKey(const Key('save_business')));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('save_business')), findsNothing);
        expect(find.text('សុខា ឱសថស្ថាន'), findsOneWidget);
        expect(find.textContaining('pharmacy'), findsOneWidget);

        await tester.tap(find.byKey(const Key('drive_cta')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('go_online')));
        await tester.pump();
        expect(
          find.text('បំពេញឯកសារដៃគូ និងការបណ្ដុះបណ្ដាលសិន ទើបចូលបណ្ដាញបាន។'),
          findsOneWidget,
        );

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('list_vehicle')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('boat'));
        await tester.pump();
        await tester.tap(find.byKey(const Key('vehicle_owner')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('save_vehicle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('save_vehicle')), findsNothing);
        expect(find.text('boat'), findsOneWidget);

        await tester.scrollUntilVisible(find.byKey(const Key('sign_out')), 400);
        await tester.tap(find.byKey(const Key('sign_out')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('sign_in_phone')), findsOneWidget);
      });
    },
  );

  testWidgets('open-business form shows an error when kind is blank', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _signInGoogle(tester);
      await tester.tap(find.byKey(const Key('account_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open_business')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), 'No kind');
      await tester.tap(find.byKey(const Key('save_business')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('បញ្ចូលប្រភេទ និងឈ្មោះ។'), findsOneWidget);
    });
  });

  testWidgets('a computer manages products and does not go out on a delivery', (
    tester,
  ) async {
    await _run(TargetPlatform.macOS, () async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await _signInGoogle(tester);

      expect(find.byKey(const Key('desk_home')), findsOneWidget);
      expect(find.byKey(const Key('open_business')), findsOneWidget);
      expect(find.byKey(const Key('deliver_to')), findsOneWidget);
      expect(find.byKey(const Key('drive_cta')), findsNothing);
      expect(find.byKey(const Key('jobs_cta')), findsNothing);
      expect(find.byKey(const Key('driver_signup')), findsNothing);
      expect(find.text('ទទួលការដឹក'), findsOneWidget);

      await tester.tap(find.byKey(const Key('account_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drive_cta')), findsNothing);
      expect(find.byKey(const Key('jobs_cta')), findsNothing);
      expect(find.byKey(const Key('list_vehicle')), findsOneWidget);
    });
  });

  testWidgets('driver signup asks for a vehicle before the photos', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _signInGoogle(tester);
      await tester.tap(find.byKey(const Key('account_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver_signup')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save_driver')));
      await tester.pump();
      expect(find.text('បញ្ចូលប្រភេទយាន។'), findsOneWidget);
    });
  });
}
