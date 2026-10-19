import 'dart:async';

import 'package:flutter/material.dart';

import 'art.dart';
import 'auth.dart';
import 'compliance.dart';
import 'device.dart';
import 'driver.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'shop.dart';
import 'state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final session = state.session;
    final phone = lecaOnPhone(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (session == null)
                Text(l10n.authFailed)
              else ...[
                Text(
                  session.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                Text('${session.method} · ${session.handle}'),
                const SizedBox(height: 16),
              ],
              Text(
                l10n.earnTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(l10n.earnBody),
              if (CambodiaRules.applies()) ...[
                const SizedBox(height: 8),
                Text(l10n.partnerNotice),
              ],
              const SizedBox(height: 12),
              if (phone)
                Text(
                  state.driver == null
                      ? l10n.driverUnverified
                      : switch (state.driver!.review) {
                          'pending' => l10n.reviewPending,
                          'rejected' => l10n.reviewRejected,
                          'approved' => l10n.reviewApproved,
                          _ => l10n.driverVerified,
                        },
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (phone && state.driver != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${state.driver!.legalName} · ${state.driver!.vehicleKind}',
                ),
                if (state.driver!.staffId.isNotEmpty)
                  Text('${l10n.staffIdLabel} ${state.driver!.staffId}'),
                if (state.driver!.plate.isNotEmpty)
                  Text('${l10n.plateLabel} ${state.driver!.plate}'),
                if (state.driver!.licenceNumber.isNotEmpty)
                  Text('${l10n.licenceNumber} ${state.driver!.licenceNumber}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        state.driver!.selfie,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        state.driver!.idCard,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ],
              if (phone) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('driver_signup'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DriverSignupScreen(),
                    ),
                  ),
                  child: Text(l10n.driverSignup),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('open_business'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OpenBusinessScreen(),
                  ),
                ),
                child: Text(l10n.openBusiness),
              ),
              if (phone) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('drive_cta'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DriveScreen(),
                    ),
                  ),
                  child: Text(l10n.driveCta),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('list_vehicle'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ListVehicleScreen(),
                  ),
                ),
                child: Text(l10n.listVehicle),
              ),
              if (phone) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('jobs_cta'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const JobsScreen()),
                  ),
                  child: Text(l10n.jobsCta),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                l10n.myBusinesses,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (state.businesses.isEmpty)
                Text(l10n.emptyBusinesses)
              else
                for (final b in state.businesses)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text('${b.kind} · ${b.cityId}'),
                          const SizedBox(height: 6),
                          ReplyMark(placeId: b.id),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ShopScreen(businessId: b.id),
                                  ),
                                ),
                                child: Text(l10n.addItem),
                              ),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ChatScreen(
                                      placeId: b.id,
                                      title: b.name,
                                    ),
                                  ),
                                ),
                                child: Text(l10n.chat),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Text(
                l10n.myVehicles,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (state.vehicles.isEmpty)
                Text(l10n.emptyVehicles)
              else
                for (final v in state.vehicles)
                  Card(
                    child: ListTile(
                      title: Text(v.kind),
                      subtitle: Text(
                        '${v.withDriver ? l10n.withDriver : l10n.selfDrive}'
                        '${v.autonomous ? ' · ${l10n.autonomousHint}' : ''}',
                      ),
                    ),
                  ),
              if (phone) ...[
                const SizedBox(height: 16),
                Text(
                  state.driving ? l10n.drivingOn : l10n.drivingOff,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                key: const Key('sign_out'),
                onPressed: () {
                  state.signOut();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OpenBusinessScreen extends StatefulWidget {
  const OpenBusinessScreen({super.key});

  @override
  State<OpenBusinessScreen> createState() => _OpenBusinessScreenState();
}

class _OpenBusinessScreenState extends State<OpenBusinessScreen> {
  final _name = TextEditingController();
  final _kind = TextEditingController();
  final _note = TextEditingController();
  final _sellerName = TextEditingController();
  final _sellerPhone = TextEditingController();
  final _sellerId = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = LecaScope.of(context)..clearSupplyError();
      if (_sellerName.text.isEmpty && state.keyName.isNotEmpty) {
        _sellerName.text = state.keyName;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _kind.dispose();
    _note.dispose();
    _sellerName.dispose();
    _sellerPhone.dispose();
    _sellerId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.openBusiness)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(
                height: 140,
                width: double.infinity,
                child: LecaArt(scene: LecaScene.shop),
              ),
              const SizedBox(height: 12),
              Text(l10n.openShopHint),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('open_shop_now'),
                onPressed: state.supplyLoading
                    ? null
                    : () async {
                        final kind = _kind.text.trim().isEmpty
                            ? 'shop'
                            : _kind.text;
                        final named = _name.text.trim().isEmpty
                            ? (_sellerName.text.trim().isEmpty
                                  ? 'ហាង'
                                  : _sellerName.text.trim())
                            : _name.text;
                        await state.openBusiness(
                          kind: kind,
                          name: named,
                          note: _note.text,
                          sellerName: _sellerName.text,
                          sellerPhone: _sellerPhone.text,
                          sellerId: _sellerId.text,
                        );
                        if (!context.mounted) return;
                        if (state.supplyError == null) {
                          Navigator.pop(context);
                        }
                      },
                child: Text(l10n.openShopNow),
              ),
              const SizedBox(height: 16),
              Text(l10n.businessKindHint),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final example in [
                    'restaurant',
                    'computers',
                    'baby',
                    'pharmacy',
                    'grocery',
                    'clinic',
                    'clothes',
                    'hardware',
                  ])
                    ActionChip(
                      label: Text(example),
                      onPressed: () => setState(() => _kind.text = example),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kind,
                decoration: InputDecoration(
                  labelText: l10n.businessKind,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.businessName,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (CambodiaRules.applies()) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _sellerName,
                  decoration: InputDecoration(
                    labelText: l10n.sellerName,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sellerPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.sellerPhone,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sellerId,
                  decoration: InputDecoration(
                    labelText: l10n.sellerId,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.noteLabel,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (state.supplyLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.supplyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.supplyError == 'seller_kyc'
                        ? l10n.sellerKycInvalid
                        : l10n.businessInvalid,
                    style: const TextStyle(color: Color(0xFF8B1E1E)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_business'),
                onPressed: state.supplyLoading
                    ? null
                    : () async {
                        await state.openBusiness(
                          kind: _kind.text,
                          name: _name.text,
                          note: _note.text,
                          sellerName: _sellerName.text,
                          sellerPhone: _sellerPhone.text,
                          sellerId: _sellerId.text,
                        );
                        if (!context.mounted) return;
                        if (state.supplyError == null) {
                          Navigator.pop(context);
                        }
                      },
                child: Text(l10n.saveBusiness),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DriveScreen extends StatefulWidget {
  const DriveScreen({super.key});

  @override
  State<DriveScreen> createState() => _DriveScreenState();
}

class _DriveScreenState extends State<DriveScreen> {
  late final TextEditingController _note;
  final _appeal = TextEditingController();
  bool _noteSeeded = false;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = LecaScope.of(context)..clearDriverError();
      unawaited(state.refreshTrust());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_noteSeeded) return;
    _note.text = LecaScope.of(context).driveNote;
    _noteSeeded = true;
  }

  @override
  void dispose() {
    _note.dispose();
    _appeal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.driveCta)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                state.driver == null
                    ? l10n.driverUnverified
                    : switch (state.driver!.review) {
                        'pending' => l10n.reviewPending,
                        'rejected' => l10n.reviewRejected,
                        'approved' => l10n.reviewApproved,
                        _ => l10n.driverVerified,
                      },
              ),
              if ((state.driver?.reviewNote ?? '').isNotEmpty)
                Text(state.driver!.reviewNote),
              const SizedBox(height: 8),
              Text(l10n.driveBody),
              if (driverErrorText(l10n, state.driverError) != null) ...[
                const SizedBox(height: 8),
                Text(
                  driverErrorText(l10n, state.driverError)!,
                  style: const TextStyle(color: Color(0xFF8B1E1E)),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.driveVehicleNote,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SwitchListTile(
                value: state.driving,
                title: Text(state.driving ? l10n.drivingOn : l10n.drivingOff),
                onChanged: (v) => state.setDriving(value: v, note: _note.text),
              ),
              FilledButton(
                key: const Key('go_online'),
                onPressed: () {
                  final code = state.setDriving(value: true, note: _note.text);
                  if (!context.mounted || code != null) return;
                  Navigator.pop(context);
                },
                child: Text(l10n.goOnline),
              ),
              if (state.openPartnerReports.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.appealHint,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                for (final report in state.openPartnerReports) ...[
                  const SizedBox(height: 8),
                  Text('${report.category} · ${report.status}'),
                  if (report.appeal.isNotEmpty) Text(report.appeal),
                  if (report.status == 'suspended') ...[
                    TextField(
                      controller: _appeal,
                      decoration: InputDecoration(
                        labelText: l10n.appealHint,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: Key('appeal_${report.id}'),
                        onPressed: () =>
                            state.appealReport(report.id, _appeal.text),
                        child: Text(l10n.appealSend),
                      ),
                    ),
                  ],
                ],
              ],
              if (state.driving) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const JobsScreen()),
                  ),
                  child: Text(l10n.jobsCta),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ListVehicleScreen extends StatefulWidget {
  const ListVehicleScreen({super.key});

  @override
  State<ListVehicleScreen> createState() => _ListVehicleScreenState();
}

class _ListVehicleScreenState extends State<ListVehicleScreen> {
  final _kind = TextEditingController();
  final _note = TextEditingController();
  bool _withDriver = true;
  bool _owner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LecaScope.of(context).clearSupplyError();
    });
  }

  @override
  void dispose() {
    _kind.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.listVehicle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.listVehicleBody),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final example in [
                    'car',
                    'motorcycle',
                    'bicycle',
                    'tuktuk',
                    'boat',
                  ])
                    ActionChip(
                      label: Text(example),
                      onPressed: () => setState(() => _kind.text = example),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kind,
                decoration: InputDecoration(
                  labelText: l10n.vehicleKind,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SwitchListTile(
                value: _withDriver,
                title: Text(l10n.withDriver),
                onChanged: (v) => setState(() => _withDriver = v),
              ),
              CheckboxListTile(
                key: const Key('vehicle_owner'),
                contentPadding: EdgeInsets.zero,
                value: _owner,
                title: Text(l10n.ownerConfirm),
                onChanged: (v) => setState(() => _owner = v ?? false),
              ),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.noteLabel,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (state.supplyLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (state.supplyError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    state.supplyError == 'platform_fleet'
                        ? l10n.platformFleetBlocked
                        : state.supplyError == 'owner_required'
                        ? l10n.ownerRequired
                        : l10n.vehicleInvalid,
                    style: const TextStyle(color: Color(0xFF8B1E1E)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_vehicle'),
                onPressed: state.supplyLoading
                    ? null
                    : () async {
                        await state.listVehicle(
                          kind: _kind.text,
                          withDriver: _withDriver,
                          autonomous: false,
                          note: _note.text,
                          owner: _owner,
                        );
                        if (!context.mounted) return;
                        if (state.supplyError == null) {
                          Navigator.pop(context);
                        }
                      },
                child: Text(l10n.saveVehicle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final km = state.lang.name == 'km';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobsTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                state.wholeCountry
                    ? l10n.radiusCountry
                    : l10n.radiusLabel(state.radiusKm.round()),
              ),
              const SizedBox(height: 8),
              Text(l10n.jobsBody),
              const SizedBox(height: 12),
              if (!state.driving)
                Text(l10n.jobsOffline)
              else if (state.jobsLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.jobsError != null)
                Column(
                  children: [
                    Text(
                      l10n.jobsError,
                      style: const TextStyle(color: Color(0xFF8B1E1E)),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: state.loadJobs,
                      child: Text(l10n.retry),
                    ),
                  ],
                )
              else ...[
                Text(
                  l10n.openJobs,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (state.nearbyOpenJobs.isEmpty)
                  Text(l10n.emptyJobs)
                else
                  for (final job in state.nearbyOpenJobs)
                    _JobCard(job: job, km: km, l10n: l10n, state: state),
                const SizedBox(height: 16),
                Text(
                  l10n.acceptedJobs,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (state.acceptedJobs.isEmpty)
                  Text(l10n.emptyAcceptedJobs)
                else
                  for (final job in state.acceptedJobs)
                    Card(
                      child: ListTile(
                        title: Text(job.titleFor(km: km)),
                        subtitle: Text(
                          '${job.kind} · ${job.detailFor(km: km)} · ${l10n.jobAccepted}',
                        ),
                        trailing: Text(moneyUsd(job.usd)),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.km,
    required this.l10n,
    required this.state,
  });

  final OperatorJob job;
  final bool km;
  final AppLocalizations l10n;
  final LecaState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.titleFor(km: km),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${job.kind} · ${job.detailFor(km: km)} · ${moneyUsd(job.usd)}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton(
                  key: Key('accept_job_${job.id}'),
                  onPressed: () => state.acceptJob(job.id),
                  child: Text(l10n.acceptJob),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: Key('decline_job_${job.id}'),
                  onPressed: () => state.declineJob(job.id),
                  child: Text(l10n.declineJob),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(
                          placeId: job.talkRoom,
                          title: l10n.talkWith,
                          fareKey: 'job:${job.id}',
                          appUsd: job.usd,
                        ),
                      ),
                    );
                  },
                  child: Text(l10n.talkWith),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
