import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/driver.dart';
import 'package:leca/identity.dart';
import 'package:leca/main.dart';
import 'package:leca/state.dart';

final _pngA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _pngB = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

Future<void> _run(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _google(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const LecaApp());
  await tester.pump();
  await tester.tap(find.byKey(const Key('open_sign_in')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sign_in_google')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open_market')));
  await tester.pumpAndSettle();
}

Future<void> _english(WidgetTester tester) async {
  await tester.tap(find.text('EN'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => PhotoPick.override = null);

  testWidgets(
    'English search hides Siem Reap until the radius is the country',
    (tester) async {
      await _run(TargetPlatform.android, () async {
        await _google(tester);
        await _english(tester);
        expect(find.text('Rides'), findsOneWidget);
        expect(find.text('Send anything'), findsOneWidget);

        await tester.enterText(find.byType(TextField).first, 'amok');
        await tester.pump();
        expect(find.text('Nothing matches'), findsOneWidget);
        expect(find.text('Angkor Khmer kitchen'), findsNothing);

        tester.widget<Slider>(find.byType(Slider)).onChanged!(
          LecaState.countryWide,
        );
        await tester.pump();
        expect(find.text('All of Cambodia'), findsWidgets);
        expect(find.text('Angkor Khmer kitchen'), findsOneWidget);

        await tester.tap(find.text('Angkor Khmer kitchen'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add').first);
        await tester.pump();
        expect(find.text('Order'), findsOneWidget);
        await tester.tap(find.text('Order'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Service fee'), findsOneWidget);
        expect(find.text('Pay with'), findsOneWidget);
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('Visa'), findsOneWidget);
        expect(find.byKey(const Key('fare_proof')), findsOneWidget);
        await tester.tap(find.text('Cash'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Cash'), findsWidgets);
      });
    },
  );

  testWidgets('a parcel checkout has a fare proof and no driver card', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _google(tester);
      await tester.tap(find.text('ផ្ញើអ្វីក៏បាន'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dropoff')), findsOneWidget);
      await tester.tap(find.byKey(const Key('dropoff')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('កែប').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('បញ្ជាទិញ'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fare_proof')), findsOneWidget);
      expect(find.byKey(const Key('ride_partner')), findsNothing);
      expect(find.text('ACLEDA'), findsOneWidget);
      expect(find.byKey(const Key('talk_with')), findsOneWidget);
    });
  });

  testWidgets('kitchen chat sends words and a voice line', (tester) async {
    await _run(TargetPlatform.android, () async {
      await _google(tester);
      await _english(tester);
      await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('talk_proof')), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'on my way');
      await tester.tap(find.byKey(const Key('send_chat')));
      await tester.pump();
      expect(find.textContaining('on my way'), findsOneWidget);
      expect(find.byKey(const Key('talk_proof')), findsOneWidget);

      await tester.tap(find.byKey(const Key('talk_voice')));
      await tester.pump();
      expect(find.text('sokha: voice'), findsOneWidget);
      await tester.tap(find.byKey(const Key('talk_video')));
      await tester.pump();
      expect(find.text('sokha: video'), findsOneWidget);
    });
  });

  testWidgets('email register rejects a short password, then signs in', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const LecaApp());
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_sign_in')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('មិនទាន់មានគណនី?'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('sign_in_email')),
        'ada@leca.app',
      );
      await tester.enterText(
        find.byKey(const Key('sign_in_email_password')),
        'short',
      );
      await tester.enterText(
        find.byKey(const Key('sign_in_email_name')),
        'Ada',
      );
      await tester.tap(find.byKey(const Key('sign_in_email_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('ពាក្យសម្ងាត់ត្រូវមានយ៉ាងតិច ៨ តួ។'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('sign_in_email_password')),
        'correct-horse',
      );
      await tester.tap(find.byKey(const Key('sign_in_email_submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_account')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });

  testWidgets('a key name signs in as that person', (tester) async {
    await _run(TargetPlatform.android, () async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const LecaApp());
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_sign_in')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('sign_in_key_name')),
        'Dara Kem',
      );
      await tester.tap(find.byKey(const Key('sign_in_key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_account')));
      await tester.pumpAndSettle();
      expect(find.text('Dara Kem'), findsWidgets);
    });
  });

  testWidgets('telegram, X, and Facebook each open the home', (tester) async {
    await _run(TargetPlatform.android, () async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      for (final key in ['sign_in_telegram', 'sign_in_x', 'sign_in_facebook']) {
        await tester.pumpWidget(const LecaApp());
        await tester.pump();
        await tester.tap(find.byKey(const Key('open_sign_in')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('chat_account')), findsOneWidget);
        await tester.tap(find.byKey(const Key('chat_account')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.byKey(const Key('sign_out')), 400);
        await tester.tap(find.byKey(const Key('sign_out')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('open_sign_in')), findsOneWidget);
      }
    });
  });

  testWidgets('a ride can be reported, and the partner card changes', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _google(tester);
      await tester.tap(find.text('ជិះ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('បញ្ជាទិញ').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ride_partner')), findsOneWidget);
      expect(find.textContaining('2A-4521'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('report_harassment')));
      await tester.tap(find.byKey(const Key('report_harassment')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ផ្អាកដៃគូ'), findsOneWidget);
      expect(find.textContaining('2A-4521'), findsNothing);
      expect(find.byKey(const Key('ride_partner')), findsOneWidget);
    });
  });

  testWidgets('the customer can ask a lower rental fare and then end it', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      await _google(tester);
      await tester.tap(find.text('ជួលយាន'));
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'fare_field_rent:car:driver:',
            ),
      );
      await tester.scrollUntilVisible(
        field.first,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(field.first, '9.50');
      final propose = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'fare_propose_rent:car:driver:',
            ),
      );
      await tester.tap(propose.first);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'fare_ask_rent:car:driver:',
              ),
        ),
        findsOneWidget,
      );
      final end = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'fare_end_rent:car:driver:',
            ),
      );
      await tester.tap(end.first);
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'fare_ended_rent:car:driver:',
              ),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a computer picks Kep as the delivery city', (tester) async {
    await _run(TargetPlatform.linux, () async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await _google(tester);
      expect(find.byKey(const Key('desk_home')), findsOneWidget);
      expect(find.byKey(const Key('drive_cta')), findsNothing);
      await tester.tap(find.byKey(const Key('deliver_to')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('កែប').last);
      await tester.pumpAndSettle();
      expect(find.text('កែប'), findsWidgets);
      expect(find.byKey(const Key('search_radius')), findsOneWidget);
    });
  });

  testWidgets('a bicycle partner signs the file and takes a nearby job', (
    tester,
  ) async {
    await _run(TargetPlatform.android, () async {
      var photos = 0;
      PhotoPick.override = () async {
        photos += 1;
        return photos.isOdd ? _pngA : _pngB;
      };
      await _google(tester);
      await tester.tap(find.byKey(const Key('account_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('driver_signup')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vehicle_bicycle')));
      await tester.pump();
      final fields = find.descendant(
        of: find.byType(DriverSignupScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Sokha Meas');
      await tester.enterText(fields.at(1), 'Sokha Meas');
      await tester.enterText(fields.at(2), '123456789');
      await tester.enterText(fields.at(3), '012345678');
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile).first,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('train_all')));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('បន្ថែមរូប').first,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('បន្ថែមរូប').at(0));
      await tester.pump();
      await tester.tap(find.text('បន្ថែមរូប').at(0));
      await tester.pump();
      expect(find.byType(Image), findsNWidgets(2));

      await tester.scrollUntilVisible(
        find.byKey(const Key('save_driver')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.runAsync(() async {
        tester
            .widget<FilledButton>(find.byKey(const Key('save_driver')))
            .onPressed!();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.byType(DriverSignupScreen), findsNothing);
      expect(find.textContaining('LECA-KH-456789'), findsWidgets);

      await tester.tap(find.byKey(const Key('drive_cta')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('go_online')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('jobs_cta')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('jobs_cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('accept_job_j_food')), findsOneWidget);
      expect(find.byKey(const Key('accept_job_j_ride')), findsOneWidget);
      await tester.tap(find.byKey(const Key('accept_job_j_food')));
      await tester.pump();
      expect(find.byKey(const Key('accept_job_j_food')), findsNothing);
      await tester.tap(find.byKey(const Key('decline_job_j_send')));
      await tester.pump();
      expect(find.byKey(const Key('decline_job_j_send')), findsNothing);
      expect(find.text('ដឹកនំបញ្ចុក'), findsOneWidget);
    });
  });

  testWidgets('the phone shows an iroh number', (tester) async {
    await _run(TargetPlatform.android, () async {
      await _google(tester);
      await _english(tester);
      await tester.tap(find.byKey(const Key('service_phone')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Calls are data. iroh carries the voice between the two devices.',
        ),
        findsOneWidget,
      );
      final card =
          tester
              .widget<SelectableText>(find.byKey(const Key('phone_number')))
              .data ??
          '';
      expect(
        RegExp(r'^leca1 [ybndrfg8ejkmcpqxot1uwisza345h769]{52}$')
            .hasMatch(card),
        isTrue,
        reason: 'number was "$card"',
      );
      expect(find.byKey(const Key('phone_call')), findsOneWidget);
    });
  });
}
