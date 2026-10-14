import 'dart:convert';
import 'dart:io';

import 'package:leca_auth/leca_auth.dart';
import 'package:leca_auth/trust.dart';
import 'package:test/test.dart';

final _png = base64Encode(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

void main() {
  test('a person approves a driver file, and a report can be appealed', () {
    final dir = Directory.systemTemp.createTempSync('leca-trust');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/trust.json';
    var store = TrustStore(path: path, adminKey: 'k');
    const rider = AuthUser(
      id: 'phone:1',
      method: 'phone',
      displayName: 'Ada',
      handle: '1',
    );
    const driver = AuthUser(
      id: 'phone:2',
      method: 'phone',
      displayName: 'Bo',
      handle: '2',
    );
    final submitted = store.submitDriver(driver, {
      'staffId': 'LECA-KH-22',
      'vehicleKind': 'car',
      'legalName': 'Bo',
      'selfie': _png,
      'idCard': _png,
      'licencePhoto': _png,
    });
    expect(submitted['review'], 'pending');
    expect(store.status(driver)['review'], 'pending');
    store.requireAdmin('k');
    expect(store.queue(), hasLength(1));
    store.reviewDriver({'userId': driver.id, 'decision': 'approved'});
    expect(store.status(driver)['review'], 'approved');

    final report = store.fileReport(rider, {
      'category': 'harassment',
      'subjectId': 'LECA-KH-22',
    });
    expect(report['status'], 'suspended');
    expect(store.isSuspended('LECA-KH-22'), isTrue);
    expect(
      () => store.appeal(rider, {'id': report['id'], 'note': 'not me'}),
      throwsA(predicate<AuthFailure>((e) => e.code == 'forbidden')),
    );
    store.appeal(driver, {'id': report['id'], 'note': 'wrong person'});
    expect(store.openReports().single['status'], 'appealed');
    store.resolveReport({'id': report['id'], 'decision': 'cleared'});
    expect(store.isSuspended('LECA-KH-22'), isFalse);
    expect(
      () => store.fileReport(rider, {
        'category': 'violence',
        'subjectId': 'LECA-KH-999999',
      }),
      throwsA(predicate<AuthFailure>((e) => e.code == 'report_unknown')),
    );

    store = TrustStore(path: path, adminKey: 'k');
    expect(store.status(driver)['review'], 'approved');
    expect(store.suspended(), isEmpty);
  });
}
