import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// `true` when the face check passed, `false` when it was declined,
/// `null` when this device has no face recognition.
class FaceGate {
  const FaceGate();

  Future<bool?> confirm() async => null;
}

class PlatformFaceGate extends FaceGate {
  const PlatformFaceGate();

  @override
  Future<bool?> confirm() async {
    final auth = LocalAuthentication();
    try {
      final kinds = await auth.getAvailableBiometrics();
      if (!kinds.contains(BiometricType.face)) return null;
      return await auth.authenticate(
        localizedReason: 'Confirm it is you',
        biometricOnly: true,
      );
    } on LocalAuthException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
