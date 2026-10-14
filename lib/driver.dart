import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'compliance.dart';
import 'identity.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'state.dart';

String? driverErrorText(AppLocalizations l10n, String? code) {
  switch (code) {
    case 'vehicle_invalid':
      return l10n.vehicleInvalid;
    case 'phone_invalid':
      return l10n.authPhoneInvalid;
    case 'photo_missing':
      return l10n.identityPhotoMissing;
    case 'photo_same':
      return l10n.identityPhotoSame;
    case 'photo_invalid':
      return l10n.identityPhotoInvalid;
    case 'name_mismatch':
      return l10n.identityNameMismatch;
    case 'id_invalid':
      return l10n.identityIdInvalid;
    case 'licence_invalid':
      return l10n.licenceInvalid;
    case 'plate_invalid':
      return l10n.plateInvalid;
    case 'registration_invalid':
      return l10n.registrationInvalid;
    case 'inspection_invalid':
      return l10n.inspectionInvalid;
    case 'transport_cert_invalid':
      return l10n.transportCertInvalid;
    case 'insurance_invalid':
      return l10n.insuranceInvalid;
    case 'logo_required':
      return l10n.logoRequired;
    case 'partner_required':
      return l10n.partnerRequired;
    case 'training_required':
      return l10n.trainingRequired;
    case 'online_blocked':
      return l10n.onlineBlocked;
    default:
      return null;
  }
}

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _legal = TextEditingController();
  final _onCard = TextEditingController();
  final _idNumber = TextEditingController();
  final _phone = TextEditingController();
  final _licence = TextEditingController();
  final _plate = TextEditingController();
  final _registration = TextEditingController();
  final _inspection = TextEditingController();
  final _domestic = TextEditingController();
  final _insurance = TextEditingController();
  String _vehicle = '';
  Uint8List? _selfie;
  Uint8List? _idCard;
  bool _logo = false;
  bool _partner = false;
  bool _traffic = false;
  bool _drivingSkill = false;
  bool _service = false;
  bool _conduct = false;

  bool _onCardEdited = false;

  @override
  void initState() {
    super.initState();
    _legal.addListener(_mirrorName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = ChowScope.of(context);
      state.clearDriverError();
      _prefill(state);
    });
  }

  /// Start from what the account already knows. Nothing to retype.
  void _prefill(ChowState state) {
    final session = state.session;
    if (session == null) return;
    if (_legal.text.isEmpty) _legal.text = session.displayName;
    final digits = session.handle.replaceAll(RegExp(r'[^\d+]'), '');
    if (_phone.text.isEmpty &&
        session.method == 'phone' &&
        digits.length >= 8) {
      _phone.text = session.handle;
    }
    setState(() {});
  }

  /// Name on the ID follows the legal name until the driver edits it.
  void _mirrorName() {
    if (_onCardEdited) return;
    if (_onCard.text != _legal.text) _onCard.text = _legal.text;
  }

  /// The one thing still missing, so the driver knows the next tap.
  String? _nextStep(AppLocalizations l10n) {
    if (_vehicle.isEmpty) return l10n.vehicleInvalid;
    if (_legal.text.trim().isEmpty) return l10n.legalName;
    if (_idNumber.text.trim().length < 6) return l10n.idNumber;
    if (_phone.text.replaceAll(RegExp(r'\D'), '').length < 8) {
      return l10n.authPhoneLabel;
    }
    if (_selfie == null) return l10n.selfiePhoto;
    if (_idCard == null) return l10n.idCardPhoto;
    final code = CambodiaRules.checkPartner(
      vehicleKind: _vehicle,
      licenceNumber: _licence.text,
      plate: _plate.text,
      registration: _registration.text,
      inspection: _inspection.text,
      domesticCert: _domestic.text,
      insurance: _insurance.text,
      logoOnVehicle: _logo,
      independentPartner: _partner,
      trainedTrafficLaw: _traffic,
      trainedDriving: _drivingSkill,
      trainedService: _service,
      trainedConduct: _conduct,
    );
    return driverErrorText(l10n, code);
  }

  @override
  void dispose() {
    _legal.removeListener(_mirrorName);
    _legal.dispose();
    _onCard.dispose();
    _idNumber.dispose();
    _phone.dispose();
    _licence.dispose();
    _plate.dispose();
    _registration.dispose();
    _inspection.dispose();
    _domestic.dispose();
    _insurance.dispose();
    super.dispose();
  }

  Future<void> _pick(bool selfie) async {
    final bytes = await PhotoPick.image();
    if (!mounted || bytes == null) return;
    setState(() {
      if (selfie) {
        _selfie = bytes;
      } else {
        _idCard = bytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    final error = driverErrorText(l10n, state.driverError);
    final kh = CambodiaRules.applies();
    final motor = kh && CambodiaRules.needsMotorFile(_vehicle);
    final inspection = kh && CambodiaRules.needsInspection(_vehicle);
    final domestic = kh && CambodiaRules.needsDomesticCert(_vehicle);
    final next = _nextStep(l10n);
    final allTrained = _traffic && _drivingSkill && _service && _conduct;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.driverSignup)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.driverSignupBody),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final offer in MarketConfig.active.regularVehicles)
                    ChoiceChip(
                      key: Key('vehicle_${offer.id}'),
                      label: Text(offer.nameFor(state.locale)),
                      selected: _vehicle == offer.id,
                      onSelected: (_) => setState(() => _vehicle = offer.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _field(_legal, l10n.legalName),
              const SizedBox(height: 12),
              _field(
                _onCard,
                l10n.nameOnId,
                onChanged: (_) => _onCardEdited = true,
              ),
              const SizedBox(height: 12),
              _field(_idNumber, l10n.idNumber),
              const SizedBox(height: 12),
              _field(
                _phone,
                l10n.authPhoneLabel,
                keyboard: TextInputType.phone,
              ),
              if (kh && _vehicle.isNotEmpty) ...[
                const SizedBox(height: 16),
                if (motor) ...[
                  _field(_licence, l10n.licenceNumber),
                  const SizedBox(height: 12),
                  _field(_plate, l10n.plateNumber),
                  const SizedBox(height: 12),
                  _field(_registration, l10n.registrationNumber),
                  const SizedBox(height: 12),
                  if (inspection) ...[
                    _field(_inspection, l10n.inspectionNumber),
                    const SizedBox(height: 12),
                  ],
                  if (domestic) ...[
                    _field(_domestic, l10n.domesticCertNumber),
                    const SizedBox(height: 12),
                  ],
                  _field(_insurance, l10n.insuranceNumber),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _logo,
                    title: Text(l10n.logoConfirm),
                    onChanged: (v) => setState(() => _logo = v ?? false),
                  ),
                ],
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _partner,
                  title: Text(l10n.partnerConfirm),
                  onChanged: (v) => setState(() => _partner = v ?? false),
                ),
                CheckboxListTile(
                  key: const Key('train_all'),
                  contentPadding: EdgeInsets.zero,
                  value: allTrained,
                  title: Text(l10n.trainAll),
                  onChanged: (v) => setState(() {
                    _traffic = _drivingSkill = _service = _conduct = v ?? false;
                  }),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _traffic,
                  title: Text(l10n.trainTraffic),
                  onChanged: (v) => setState(() => _traffic = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _drivingSkill,
                  title: Text(l10n.trainDriving),
                  onChanged: (v) => setState(() => _drivingSkill = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _service,
                  title: Text(l10n.trainService),
                  onChanged: (v) => setState(() => _service = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _conduct,
                  title: Text(l10n.trainConduct),
                  onChanged: (v) => setState(() => _conduct = v ?? false),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _photoSlot(
                    label: l10n.selfiePhoto,
                    bytes: _selfie,
                    onPick: () => _pick(true),
                  ),
                  const SizedBox(width: 12),
                  _photoSlot(
                    label: l10n.idCardPhoto,
                    bytes: _idCard,
                    onPick: () => _pick(false),
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error,
                    style: const TextStyle(color: Color(0xFF8B1E1E)),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                next == null ? l10n.signupReady : l10n.signupNext(next),
                key: const Key('signup_next'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('save_driver'),
                onPressed: () async {
                  final code = await state.registerDriver(
                    legalName: _legal.text,
                    nameOnId: _onCard.text,
                    idNumber: _idNumber.text,
                    phone: _phone.text,
                    vehicleKind: _vehicle,
                    selfie: _selfie,
                    idCard: _idCard,
                    licenceNumber: _licence.text,
                    plate: _plate.text,
                    registration: _registration.text,
                    inspection: _inspection.text,
                    domesticCert: _domestic.text,
                    insurance: _insurance.text,
                    logoOnVehicle: _logo,
                    independentPartner: _partner,
                    trainedTrafficLaw: _traffic,
                    trainedDriving: _drivingSkill,
                    trainedService: _service,
                    trainedConduct: _conduct,
                  );
                  if (!context.mounted || code != null) return;
                  Navigator.pop(context);
                },
                child: Text(l10n.saveDriver),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: (value) {
        onChanged?.call(value);
        setState(() {});
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _photoSlot({
    required String label,
    required Uint8List? bytes,
    required VoidCallback onPick,
  }) {
    final l10n = AppLocalizations.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x1A1A1410)),
                ),
                clipBehavior: Clip.antiAlias,
                child: bytes == null
                    ? Text(l10n.pickPhoto)
                    : Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
