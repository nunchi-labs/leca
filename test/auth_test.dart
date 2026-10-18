import 'package:leca/auth.dart';
import 'package:leca/device_key.dart';
import 'package:leca/face_gate.dart';
import 'package:leca/state.dart';
import 'package:leca/vault.dart';
import 'package:flutter_test/flutter_test.dart';

class _Face extends FaceGate {
  const _Face(this.answer);

  final bool? answer;

  @override
  Future<bool?> confirm() async => answer;
}

void main() {
  test('AuthConfig is mock when dart-defines are empty', () {
    expect(AuthConfig.googleLive, isFalse);
    expect(AuthConfig.facebookLive, isFalse);
    expect(AuthConfig.whatsappLive, isFalse);
    expect(AuthConfig.liveFor('google'), isFalse);
    expect(AuthConfig.liveFor('whatsapp'), isFalse);
    expect(AuthConfig.liveFor('telegram'), isFalse);
    expect(AuthConfig.liveFor('x'), isFalse);
    expect(AuthConfig.liveFor('wechat'), isFalse);
  });

  test('Google mock sign-in creates a session', () async {
    final state = LecaState();
    expect(state.signedIn, isFalse);
    final future = state.signIn(method: 'google', handle: 'sokha@leca.app');
    expect(state.authLoading, isTrue);
    await future;
    expect(state.session?.method, 'google');
    expect(state.session?.displayName, 'sokha');
    expect(state.authLoading, isFalse);
  });

  test(
    'email register then sign-in, and a wrong password is rejected',
    () async {
      final state = LecaState();
      await state.signIn(
        method: 'email',
        handle: 'Sokha@Leca.app',
        password: 'short',
        register: true,
      );
      expect(state.authError, 'password_short');
      await state.signIn(
        method: 'email',
        handle: 'Sokha@Leca.app',
        password: 'correct-horse',
        name: 'Sokha',
        register: true,
      );
      expect(state.session?.method, 'email');
      expect(state.session?.handle, 'sokha@leca.app');
      expect(state.session?.displayName, 'Sokha');
      state.signOut();
      await state.signIn(
        method: 'email',
        handle: 'sokha@leca.app',
        password: 'wrong-password',
      );
      expect(state.authError, 'credentials_invalid');
      expect(state.session, isNull);
      await state.signIn(
        method: 'email',
        handle: 'sokha@leca.app',
        password: 'correct-horse',
      );
      expect(state.session?.id, 'email:sokha@leca.app');
    },
  );

  test('WeChat mock sign-in creates a session', () async {
    final state = LecaState();
    await state.signIn(method: 'wechat', handle: 'sokha.wx@leca.app');
    expect(state.session?.method, 'wechat');
    expect(state.session?.displayName, 'sokha.wx');
    expect(state.session?.token, isNull);
  });

  test('phone mock sends a code then verifies', () async {
    final state = LecaState();
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
    final state = LecaState();
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

  test(
    'device key sign-in keeps the same node, with or without a name',
    () async {
      expect(
        keyProofMessage(challenge: 'c', publicKey: 'p', name: 'Sokha'),
        'leca-key/1\nc\np\nSokha\n',
      );
      final vault = MemoryVault();
      final state = LecaState(vault: vault);
      await state.signIn(method: 'key', handle: '', name: '');
      final id = state.session?.id;
      expect(id, startsWith('key:'));
      expect(state.session?.method, 'key');
      expect(state.session?.displayName, state.session?.handle);
      expect(state.keyName, isEmpty);
      state.signOut();
      await state.save();
      final again = LecaState(vault: vault);
      await again.restore();
      expect(again.session, isNull);
      await again.signIn(method: 'key', handle: '', name: 'Sokha');
      expect(again.session?.id, id);
      expect(again.session?.displayName, 'Sokha');
      expect(again.keyName, 'Sokha');
      final key = await again.ensureDeviceKey();
      expect(key.accountId, id);
      expect(key.publicKey, hasLength(32));
      expect(key.seed, hasLength(32));
    },
  );

  test('face sign-in uses the device key after the face check', () async {
    final denied = LecaState(faceGate: const _Face(false));
    await denied.signIn(method: 'face', handle: '', name: '');
    expect(denied.authError, 'face_denied');
    expect(denied.session, isNull);

    final missing = LecaState(faceGate: const _Face(null));
    await missing.signIn(method: 'face', handle: '', name: 'Ada');
    expect(missing.authError, 'face_unavailable');

    final state = LecaState(faceGate: const _Face(true));
    await state.signIn(method: 'face', handle: '', name: 'Ada');
    expect(state.session?.method, 'face');
    expect(state.session?.displayName, 'Ada');
    expect(state.session?.id, startsWith('key:'));
    await state.signIn(method: 'passkey', handle: '');
    expect(state.authError, 'passkey_unavailable');
    expect(state.session?.method, 'face');
  });

  test('going online stays closed without a Cambodia partner file', () async {
    final state = LecaState();
    await state.loadJobs();
    expect(state.jobsError, 'jobs_offline');
    expect(state.setDriving(value: true, note: 'tuktuk'), 'online_blocked');
    expect(state.driving, isFalse);
    expect(state.openJobs, isEmpty);
  });
}
