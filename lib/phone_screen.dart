import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth.dart';
import 'auth_api.dart';
import 'l10n/app_localizations.dart';
import 'phone.dart';
import 'state.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _dial = TextEditingController();
  List<PhoneAddress> _choices = const [];
  String? _lookup;

  @override
  void dispose() {
    _dial.dispose();
    super.dispose();
  }

  Future<void> _place([PhoneAddress? picked]) async {
    final handset = PhoneScope.of(context);
    final state = LecaScope.of(context);
    final targets = picked == null
        ? await resolvePhone(
            raw: _dial.text,
            contacts: state.phoneContacts,
            lookup: (query) => _lookupPhones(query, state.session?.token),
          )
        : [picked];
    if (!mounted) return;
    if (picked == null && targets.length > 1) {
      setState(() {
        _choices = targets;
        _lookup = null;
      });
      return;
    }
    if (targets.isEmpty || targets.first.addr.isEmpty) {
      setState(() => _lookup = 'unreachable');
      return;
    }
    setState(() {
      _choices = const [];
      _lookup = null;
    });
    await handset.dial(targets.first, myName: state.session?.displayName ?? '');
  }

  Future<List<PhoneAddress>> _lookupPhones(String query, String? token) async {
    if (!AuthConfig.apiLive || token == null || token.isEmpty) return const [];
    try {
      final raw = await AuthApi.get(
        '/v1/phone/find?q=${Uri.encodeQueryComponent(query)}',
        token: token,
      );
      return phoneMatches(raw['matches']);
    } on Object catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final handset = PhoneScope.of(context);
    final fault = _faultText(l10n, handset.fault) ?? _lookupText(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.phoneTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(l10n.phoneData),
              const SizedBox(height: 4),
              Text(
                l10n.phoneHeadset,
                style: const TextStyle(color: Color(0xFF5C534C)),
              ),
              if (handset.wire == Wire.absent) ...[
                const SizedBox(height: 8),
                Text(kIsWeb ? l10n.phoneWeb : l10n.phoneOffline),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.phoneYourNumber,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              SelectableText(
                handset.card.isEmpty ? '…' : handset.card,
                key: const Key('phone_number'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  key: const Key('phone_copy'),
                  onPressed: handset.card.isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(
                            ClipboardData(text: handset.card),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.phoneCopied)),
                          );
                        },
                  child: Text(l10n.phoneCopy),
                ),
              ),
              if (handset.phase != CallPhase.idle) ...[
                const SizedBox(height: 16),
                _LiveCall(l10n: l10n, handset: handset),
              ],
              if (fault != null) ...[
                const SizedBox(height: 12),
                Text(fault, key: const Key('phone_fault')),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('phone_dial'),
                controller: _dial,
                decoration: InputDecoration(
                  hintText: l10n.phoneHint,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('phone_call'),
                onPressed: handset.phase == CallPhase.idle
                    ? () => unawaited(_place())
                    : null,
                child: Text(l10n.phoneCall),
              ),
              for (final choice in _choices)
                ListTile(
                  title: Text(
                    choice.name.isEmpty
                        ? phoneShort(choice.endpoint)
                        : choice.name,
                  ),
                  subtitle: Text(phoneShort(choice.endpoint)),
                  onTap: () => unawaited(_place(choice)),
                ),
              const SizedBox(height: 20),
              Text(
                l10n.phoneContacts,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (state.phoneContacts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.phoneEmpty),
                )
              else
                for (final contact in state.phoneContacts)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      contact.name.isEmpty
                          ? phoneShort(contact.endpoint)
                          : contact.name,
                    ),
                    subtitle: Text(phoneShort(contact.endpoint)),
                    onTap: contact.addr.isEmpty
                        ? null
                        : () => unawaited(
                            _place(
                              PhoneAddress(
                                endpoint: contact.endpoint,
                                addr: contact.addr,
                                name: contact.name,
                              ),
                            ),
                          ),
                  ),
              const SizedBox(height: 12),
              Text(
                l10n.phoneRecent,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (state.phoneLog.isEmpty)
                const SizedBox(height: 8)
              else
                for (final record in state.phoneLog)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      record.name.isEmpty
                          ? phoneShort(record.endpoint)
                          : record.name,
                    ),
                    subtitle: Text(
                      '${_wayText(l10n, record.way)} · ${phoneClock(record.seconds)}',
                    ),
                    onTap: record.addr.isEmpty
                        ? null
                        : () => unawaited(
                            _place(
                              PhoneAddress(
                                endpoint: record.endpoint,
                                addr: record.addr,
                                name: record.name,
                              ),
                            ),
                          ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  String? _lookupText(AppLocalizations l10n) {
    if (_lookup == 'unreachable') return l10n.phoneUnreachable;
    return null;
  }
}

class PhoneShell extends StatelessWidget {
  const PhoneShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final handset = PhoneScope.of(context);
    return Stack(
      children: [
        child,
        if (handset.phase != CallPhase.idle)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: PhoneBanner(handset: handset)),
          ),
      ],
    );
  }
}

class PhoneBanner extends StatelessWidget {
  const PhoneBanner({required this.handset, super.key});

  final Handset handset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = handset.shownPeer;
    final label = switch (handset.phase) {
      CallPhase.dialing => l10n.phoneDialing(name),
      CallPhase.ringing => l10n.phoneRinging(name),
      CallPhase.live => '${l10n.phoneLive} ${phoneClock(handset.seconds)}',
      CallPhase.idle => '',
    };
    return Material(
      key: const Key('phone_banner'),
      elevation: 6,
      color: const Color(0xFF1A1410),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (handset.phase == CallPhase.ringing) ...[
              TextButton(
                key: const Key('phone_accept'),
                onPressed: handset.accept,
                child: Text(l10n.phoneAccept),
              ),
              TextButton(
                key: const Key('phone_decline'),
                onPressed: handset.decline,
                child: Text(l10n.phoneDecline),
              ),
            ],
            if (handset.phase == CallPhase.dialing ||
                handset.phase == CallPhase.live)
              TextButton(
                key: const Key('phone_hangup'),
                onPressed: handset.hangup,
                child: Text(l10n.phoneHangup),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveCall extends StatelessWidget {
  const _LiveCall({required this.l10n, required this.handset});

  final AppLocalizations l10n;
  final Handset handset;

  @override
  Widget build(BuildContext context) {
    final name = handset.shownPeer;
    final label = switch (handset.phase) {
      CallPhase.dialing => l10n.phoneDialing(name),
      CallPhase.ringing => l10n.phoneRinging(name),
      CallPhase.live => '${l10n.phoneLive} ${phoneClock(handset.seconds)}',
      CallPhase.idle => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            if (handset.phase == CallPhase.ringing) ...[
              FilledButton(
                onPressed: handset.accept,
                child: Text(l10n.phoneAccept),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: handset.decline,
                child: Text(l10n.phoneDecline),
              ),
            ],
            if (handset.phase == CallPhase.live)
              OutlinedButton(
                key: const Key('phone_mute'),
                onPressed: handset.toggleMute,
                child: Text(handset.muted ? l10n.phoneMuted : l10n.phoneMute),
              ),
            if (handset.phase == CallPhase.dialing ||
                handset.phase == CallPhase.live) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: handset.hangup,
                child: Text(l10n.phoneHangup),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String? _faultText(AppLocalizations l10n, PhoneFault fault) {
  return switch (fault) {
    PhoneFault.none => null,
    PhoneFault.busy => l10n.phoneBusy,
    PhoneFault.unreachable => l10n.phoneUnreachable,
    PhoneFault.declined => l10n.phoneDeclined,
    PhoneFault.self => l10n.phoneSelf,
    PhoneFault.offline => l10n.phoneOffline,
    PhoneFault.gear => l10n.phoneGear,
    PhoneFault.timeout => l10n.phoneTimeout,
  };
}

String _wayText(AppLocalizations l10n, CallWay way) {
  return switch (way) {
    CallWay.incoming => l10n.phoneWayIn,
    CallWay.outgoing => l10n.phoneWayOut,
    CallWay.missed => l10n.phoneWayMissed,
  };
}
