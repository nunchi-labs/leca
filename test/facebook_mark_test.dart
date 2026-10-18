import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leca/facebook_mark.dart';
import 'package:leca/main.dart';

void main() {
  test('facebook logo is a blue disc with an f-shaped hole', () {
    final path = facebookLogoPath();
    expect(path.contains(const Offset(0.5, 0.5)), isFalse);
    expect(path.contains(const Offset(8.5, 2.5)), isTrue);
    expect(path.contains(const Offset(4.5, 12.5)), isTrue);
    expect(path.contains(const Offset(12.5, 12.5)), isFalse);
  });

  testWidgets('facebook mark stays 16px on the sign-in button', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const LecaApp());
    await tester.pump();
    expect(find.byKey(const Key('sign_in_facebook')), findsOneWidget);
    await tester.pump();
    expect(tester.getSize(find.byType(FacebookMark)), const Size(16, 16));
    expect(tester.takeException(), isNull);
  });
}
