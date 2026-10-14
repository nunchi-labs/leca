import 'package:chow/auth.dart';
import 'package:chow/state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthConfig is mock when dart-defines are empty', () {
    expect(AuthConfig.googleLive, isFalse);
    expect(AuthConfig.facebookLive, isFalse);
    expect(AuthConfig.smsLive, isFalse);
    expect(AuthConfig.liveFor('google'), isFalse);
    expect(AuthConfig.liveFor('phone'), isFalse);
    expect(AuthConfig.liveFor('wechat'), isFalse);
  });

  test('Google mock sign-in creates a session', () async {
    final state = ChowState();
    expect(state.signedIn, isFalse);
    final future = state.signIn(method: 'google', handle: 'sokha@chow.app');
    expect(state.authLoading, isTrue);
    await future;
    expect(state.session?.method, 'google');
    expect(state.session?.displayName, 'sokha');
    expect(state.authLoading, isFalse);
  });

  test(
    'email register then sign-in, and a wrong password is rejected',
    () async {
      final state = ChowState();
      await state.signIn(
        method: 'email',
        handle: 'Sokha@Chow.app',
        password: 'short',
        register: true,
      );
      expect(state.authError, 'password_short');
      await state.signIn(
        method: 'email',
        handle: 'Sokha@Chow.app',
        password: 'correct-horse',
        name: 'Sokha',
        register: true,
      );
      expect(state.session?.method, 'email');
      expect(state.session?.handle, 'sokha@chow.app');
      expect(state.session?.displayName, 'Sokha');
      state.signOut();
      await state.signIn(
        method: 'email',
        handle: 'sokha@chow.app',
        password: 'wrong-password',
      );
      expect(state.authError, 'credentials_invalid');
      expect(state.session, isNull);
      await state.signIn(
        method: 'email',
        handle: 'sokha@chow.app',
        password: 'correct-horse',
      );
      expect(state.session?.id, 'email:sokha@chow.app');
    },
  );

  test('WeChat mock sign-in creates a session', () async {
    final state = ChowState();
    await state.signIn(method: 'wechat', handle: 'sokha.wx@chow.app');
    expect(state.session?.method, 'wechat');
    expect(state.session?.displayName, 'sokha.wx');
    expect(state.session?.token, isNull);
  });

  test('phone mock sends a code then verifies', () async {
    final state = ChowState();
    await state.signIn(method: 'phone', handle: '012345678');
    expect(state.phoneCodeSent, isTrue);
    expect(state.session, isNull);
    await state.signIn(method: 'phone', handle: '012345678', code: '12');
    expect(state.authError, 'code_invalid');
    await state.signIn(method: 'phone', handle: '012345678', code: '2468');
    expect(state.session?.method, 'phone');
    expect(state.phoneCodeSent, isFalse);
  });

  test('open business and list vehicle reject blank kinds', () async {
    final state = ChowState();
    await state.openBusiness(kind: '  ', name: 'Sokha');
    expect(state.supplyError, 'business_invalid');
    expect(state.businesses, isEmpty);
    await state.openBusiness(
      kind: 'clinic',
      name: 'Sokha Clinic',
      sellerName: 'Sokha',
      sellerPhone: '012345678',
      sellerId: '123456',
    );
    expect(state.businesses.single.kind, 'clinic');
    expect(state.businesses.single.sellerName, 'Sokha');
    await state.listVehicle(kind: '', withDriver: true, autonomous: false);
    expect(state.supplyError, 'vehicle_invalid');
    await state.listVehicle(
      kind: 'kayak',
      withDriver: false,
      autonomous: true,
      owner: true,
    );
    expect(state.supplyError, 'platform_fleet');
    expect(state.vehicles, isEmpty);
    await state.listVehicle(
      kind: 'kayak',
      withDriver: false,
      autonomous: false,
      owner: true,
    );
    expect(state.vehicles.single.kind, 'kayak');
    expect(state.vehicles.single.autonomous, isFalse);
    expect(state.vehicles.single.owner, isTrue);
  });

  test('going online stays closed without a Cambodia partner file', () async {
    final state = ChowState();
    await state.loadJobs();
    expect(state.jobsError, 'jobs_offline');
    expect(state.setDriving(value: true, note: 'tuktuk'), 'online_blocked');
    expect(state.driving, isFalse);
    expect(state.openJobs, isEmpty);
  });
}
