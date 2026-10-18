import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

class PasskeyCreated {
  const PasskeyCreated({
    required this.clientDataJSON,
    required this.attestationObject,
  });

  final String clientDataJSON;
  final String attestationObject;
}

class PasskeySigned {
  const PasskeySigned({
    required this.id,
    required this.clientDataJSON,
    required this.authenticatorData,
    required this.signature,
  });

  final String id;
  final String clientDataJSON;
  final String authenticatorData;
  final String signature;
}

class PasskeyUnavailable implements Exception {
  const PasskeyUnavailable();
}

class PasskeyCancelled implements Exception {
  const PasskeyCancelled();
}

class PasskeyNone implements Exception {
  const PasskeyNone();
}

/// The platform passkey sheet. Face ID, fingerprint, or a screen lock
/// confirms the person. The private key stays on the device.
class PasskeyClient {
  const PasskeyClient();

  Future<PasskeyCreated> create({
    required String challenge,
    required String rpId,
    required String userId,
    required String name,
  }) async {
    throw const PasskeyUnavailable();
  }

  Future<PasskeySigned> sign({
    required String challenge,
    required String rpId,
  }) async {
    throw const PasskeyUnavailable();
  }
}

class PlatformPasskeyClient extends PasskeyClient {
  PlatformPasskeyClient() : _authenticator = PasskeyAuthenticator();

  final PasskeyAuthenticator _authenticator;

  @override
  Future<PasskeyCreated> create({
    required String challenge,
    required String rpId,
    required String userId,
    required String name,
  }) async {
    final label = name.isEmpty ? 'Leca' : name;
    try {
      final created = await _authenticator.register(
        RegisterRequestType(
          challenge: challenge,
          relyingParty: RelyingPartyType(name: 'Leca', id: rpId),
          user: UserType(id: userId, name: label, displayName: label),
          excludeCredentials: const [],
          authSelectionType: AuthenticatorSelectionType(
            authenticatorAttachment: 'platform',
            requireResidentKey: true,
            residentKey: 'required',
            userVerification: 'required',
          ),
          pubKeyCredParams: [
            PubKeyCredParamType(type: 'public-key', alg: -7),
            PubKeyCredParamType(type: 'public-key', alg: -8),
          ],
          attestation: 'none',
        ),
      );
      return PasskeyCreated(
        clientDataJSON: created.clientDataJSON,
        attestationObject: created.attestationObject,
      );
    } on PasskeyAuthCancelledException {
      throw const PasskeyCancelled();
    } on DeviceNotSupportedException {
      throw const PasskeyUnavailable();
    } on PasskeyUnsupportedException {
      throw const PasskeyUnavailable();
    } on NoCredentialsAvailableException {
      throw const PasskeyNone();
    }
  }

  @override
  Future<PasskeySigned> sign({
    required String challenge,
    required String rpId,
  }) async {
    try {
      final signed = await _authenticator.authenticate(
        AuthenticateRequestType(
          relyingPartyId: rpId,
          challenge: challenge,
          mediation: MediationType.Required,
          preferImmediatelyAvailableCredentials: true,
          userVerification: 'required',
          canBeSecurityKey: false,
        ),
      );
      return PasskeySigned(
        id: signed.id,
        clientDataJSON: signed.clientDataJSON,
        authenticatorData: signed.authenticatorData,
        signature: signed.signature,
      );
    } on PasskeyAuthCancelledException {
      throw const PasskeyCancelled();
    } on DeviceNotSupportedException {
      throw const PasskeyUnavailable();
    } on PasskeyUnsupportedException {
      throw const PasskeyUnavailable();
    } on NoCredentialsAvailableException {
      throw const PasskeyNone();
    }
  }
}
