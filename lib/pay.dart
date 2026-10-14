import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'compliance.dart';
import 'geo.dart';
import 'khqr.dart';
import 'l10n/app_localizations.dart';
import 'location.dart';
import 'market.dart';
import 'quote.dart';
import 'state.dart';
import 'talk_screen.dart';
import 'traffic.dart';

enum _QrPhase { loading, ready, error }

/// The rate-card kind behind a booking, or null when it was not auto-priced.
String? _quoteKind(Booking booking) {
  switch (booking.kind) {
    case BookKind.ride:
      return 'ride';
    case BookKind.send:
      return 'delivery';
    case BookKind.rent:
      if (booking.detail.startsWith('sale')) return null;
      return booking.detail.contains('self-drive') ? 'rent-self' : 'rent';
    case BookKind.goods:
      return null;
  }
}

/// The booking's quote, rebuilt on the card it was priced under. Null when
/// the booking was not auto-priced or its proof does not check out.
TripQuote? _bookingQuote(Booking booking) {
  if (booking.proof.isEmpty || booking.meters <= 0) return null;
  final kind = _quoteKind(booking);
  if (kind == null) return null;
  final card = RateCard.known[booking.card];
  if (card == null) return null;
  final vehicle = kind == 'delivery' ? '' : booking.vehicleId;
  final quote = TripQuote(
    kind: kind,
    vehicle: vehicle,
    meters: booking.meters,
    minutes: booking.minutes,
    hours: booking.hours,
    cents: card.fareCents(
      kind: kind,
      vehicle: vehicle,
      meters: booking.meters,
      minutes: booking.minutes,
      hours: booking.hours,
    ),
    proof: booking.proof,
    card: booking.card,
  );
  return quote.checksOut ? quote : null;
}

double? _automaticUsd(Booking booking) => _bookingQuote(booking)?.usd;

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  _QrPhase _phase = _QrPhase.loading;
  PayPayload? _payload;
  String? _errorCode;
  late final String _orderId;
  late final TextEditingController _note;
  Timer? _debounce;
  int _gen = 0;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final state = LecaScope.of(context);
    _orderId = state.newOrderId();
    _note = TextEditingController(text: state.note);
    state.syncRideMatch(notify: false);
    _rebuild();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_ready) _note.dispose();
    super.dispose();
  }

  Future<void> _rebuild() async {
    final token = ++_gen;
    final state = LecaScope.of(context);
    setState(() {
      _phase = _QrPhase.loading;
      _errorCode = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted || token != _gen) return;
    try {
      if (!state.hasPayable) {
        setState(() => _phase = _QrPhase.ready);
        return;
      }
      if (state.rail.kind == RailKind.cash) {
        setState(() {
          _payload = PayPayload(text: 'CASH', rail: state.rail);
          _phase = _QrPhase.ready;
        });
        return;
      }
      final payload = QrFactory.build(
        rail: state.rail,
        amountUsd: state.totalUsd,
        orderId: _orderId,
        note: _note.text,
        storeLabel: state.payableLabel,
        merchantCity: state.city.nameEn,
        market: MarketConfig.active,
      );
      if (token != _gen) return;
      setState(() {
        _payload = payload;
        _phase = _QrPhase.ready;
      });
    } on QrException catch (e) {
      setState(() {
        _errorCode = e.code;
        _phase = _QrPhase.error;
      });
    } catch (_) {
      setState(() {
        _errorCode = 'failed';
        _phase = _QrPhase.error;
      });
    }
  }

  void _onNoteChanged(String value) {
    LecaScope.of(context).setNote(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _rebuild);
  }

  String _errorText(AppLocalizations l10n) {
    if (_errorCode == 'invalid_amount') return l10n.invalidAmount;
    return l10n.errorQr;
  }

  String _hint(AppLocalizations l10n, PaymentRail rail) {
    switch (rail.kind) {
      case RailKind.stripe:
        return StripeCheckout.hasPublishableKey
            ? l10n.stripeHintLive
            : l10n.stripeHint;
      case RailKind.khqr:
        return l10n.khqrHint(rail.nameEn);
      case RailKind.generic:
        return l10n.otherHint;
      case RailKind.cash:
        return l10n.cashHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final empty = !state.hasPayable;

    final details = _Details(
      l10n: l10n,
      state: state,
      note: _note,
      onRail: (id) {
        state.setRail(id);
        _rebuild();
      },
      onNote: _onNoteChanged,
    );

    final Widget qr;
    if (empty) {
      qr = _StatusPane(
        icon: Icons.shopping_bag_outlined,
        title: l10n.emptyCartTitle,
        body: l10n.emptyCartBody,
        action: l10n.backToFood,
        onAction: () => Navigator.of(context).popUntil((r) => r.isFirst),
      );
    } else if (_phase == _QrPhase.loading) {
      qr = _StatusPane(icon: Icons.qr_code_2, title: l10n.loadingQr);
    } else if (_phase == _QrPhase.error || _payload == null) {
      qr = _StatusPane(
        icon: Icons.error_outline,
        title: _errorText(l10n),
        action: l10n.retry,
        onAction: _rebuild,
      );
    } else {
      qr = _QrPane(
        l10n: l10n,
        payload: _payload!,
        hint: _hint(l10n, state.rail),
        stripe: state.rail.kind == RailKind.stripe,
        cash: state.rail.kind == RailKind.cash,
        onPaid: () async {
          await showDialog<void>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(l10n.paidTitle),
                content: Text(l10n.paidBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.close),
                  ),
                ],
              );
            },
          );
          if (!context.mounted) return;
          state.clearCart();
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.payTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SingleChildScrollView(child: details)),
                    Expanded(child: SingleChildScrollView(child: qr)),
                  ],
                )
              : ListView(children: [details, qr]),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.l10n,
    required this.state,
    required this.note,
    required this.onRail,
    required this.onNote,
  });

  final AppLocalizations l10n;
  final LecaState state;
  final TextEditingController note;
  final ValueChanged<String> onRail;
  final ValueChanged<String> onNote;

  Future<void> _share(BuildContext context, String audience) async {
    final text = await state.shareTrip(audience);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.shareCopied)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.rideMatch != null) ...[
            _PartnerCard(l10n: l10n, state: state, onShare: _share),
            const SizedBox(height: 16),
          ],
          Text(l10n.amountLabel, style: Theme.of(context).textTheme.titleSmall),
          Text(
            '${moneyUsd(state.totalUsd)} · ${moneyKhr(state.totalUsd)}',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (state.itemCount > 0) ...[
            Text('${l10n.subtotal}  ${moneyUsd(state.subtotalUsd)}'),
            if (state.cartKitchen != null) ...[
              Text('${l10n.deliveryFee}  ${moneyUsd(state.deliveryUsd)}'),
              if ((state.deliveryUsd -
                          state.deliveryQuoteOf(state.cartKitchen!).usd)
                      .abs() >=
                  0.009)
                Text(
                  '${l10n.appPrice}  ${moneyUsd(state.deliveryQuoteOf(state.cartKitchen!).usd)}',
                ),
              if (state.deliveryQuoteOf(state.cartKitchen!).checksOut)
                Text(
                  l10n.fareProof(
                    state
                        .deliveryQuoteOf(state.cartKitchen!)
                        .proof
                        .substring(0, 12),
                  ),
                  key: const Key('fare_proof'),
                ),
            ],
            if (state.cartKitchen != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('talk_with'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => TalkScreen(
                          room: state.cartKitchen!.id,
                          title: l10n.talkWith,
                          fareKey: state.deliveryFareKey(state.cartKitchen!),
                          appUsd: state.deliveryQuoteOf(state.cartKitchen!).usd,
                        ),
                      ),
                    );
                  },
                  child: Text(l10n.talkWith),
                ),
              ),
            if (state.cartKitchen != null)
              TrafficMinutes(
                from: TripFix(
                  latitude: state.cartKitchen!.latitude,
                  longitude: state.cartKitchen!.longitude,
                ),
                to: state.origin,
                label: l10n.deliveryMinutes,
                token: state.session?.token,
              ),
          ] else if (state.booking != null) ...[
            Text(state.booking!.title),
            if (_automaticUsd(state.booking!) != null) ...[
              Text(
                '${l10n.appPrice}  ${moneyUsd(_automaticUsd(state.booking!)!)}',
              ),
              if ((state.booking!.amountUsd - _automaticUsd(state.booking!)!)
                      .abs() >=
                  0.009)
                Text(
                  '${l10n.agreedPrice}  ${moneyUsd(state.booking!.amountUsd)}',
                ),
              Text(
                l10n.fareProof(state.booking!.proof.substring(0, 12)),
                key: const Key('fare_proof'),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('talk_with'),
                onPressed: () {
                  final booking = state.booking!;
                  final room = switch (booking.kind) {
                    BookKind.ride => 'ride:${booking.vehicleId}',
                    BookKind.rent => 'rent:${booking.vehicleId}',
                    _ => 'send:${booking.detail}',
                  };
                  final auto = _automaticUsd(booking);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TalkScreen(
                        room: room,
                        title: l10n.talkWith,
                        fareKey: auto == null
                            ? null
                            : '$room:${booking.meters}:${booking.minutes}',
                        appUsd: auto ?? 0,
                      ),
                    ),
                  );
                },
                child: Text(l10n.talkWith),
              ),
            ),
          ],
          Text('${l10n.serviceFee}  ${moneyUsd(state.feeUsd)}'),
          const SizedBox(height: 8),
          Text(l10n.noWallet),
          const SizedBox(height: 16),
          Text(l10n.noteLabel),
          const SizedBox(height: 6),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 3,
            onChanged: onNote,
            decoration: InputDecoration(
              hintText: l10n.noteHint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.payWith,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rail in MarketConfig.active.rails)
                ChoiceChip(
                  label: Text(rail.nameFor(state.locale)),
                  selected: state.railId == rail.id,
                  onSelected: (_) => onRail(rail.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({
    required this.l10n,
    required this.state,
    required this.onShare,
  });

  final AppLocalizations l10n;
  final LecaState state;
  final Future<void> Function(BuildContext context, String audience) onShare;

  @override
  Widget build(BuildContext context) {
    final partner = state.rideMatch;
    if (partner == null) return const SizedBox.shrink();
    final photo = partner.photo ?? kPartnerPortrait;
    return Card(
      key: const Key('ride_partner'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.driverPhoto,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photo,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partner.nameFor(state.locale.languageCode),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text('${l10n.plateLabel} ${partner.plate}'),
                      Text('${l10n.staffIdLabel} ${partner.staffId}'),
                      Text(l10n.upfrontFare),
                      TrafficMinutes(
                        from: northOf(state.origin, 2.4),
                        to: state.origin,
                        token: state.session?.token,
                        label: (minutes) => l10n.driverMinutes(
                          partner.nameFor(state.locale.languageCode),
                          minutes,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.shareTripHint),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('share_family'),
                  onPressed: () => onShare(context, 'family'),
                  child: Text(l10n.shareFamily),
                ),
                OutlinedButton(
                  key: const Key('share_authorities'),
                  onPressed: () => onShare(context, 'authorities'),
                  child: Text(l10n.shareAuthorities),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.reportSafety,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  key: const Key('report_intoxication'),
                  onPressed: () => _report(context, 'intoxication'),
                  child: Text(l10n.reportIntoxication),
                ),
                TextButton(
                  key: const Key('report_violence'),
                  onPressed: () => _report(context, 'violence'),
                  child: Text(l10n.reportViolence),
                ),
                TextButton(
                  key: const Key('report_harassment'),
                  onPressed: () => _report(context, 'harassment'),
                  child: Text(l10n.reportHarassment),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _report(BuildContext context, String category) async {
    await state.fileSafetyReport(category);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.reportActed)));
  }
}

class _QrPane extends StatelessWidget {
  const _QrPane({
    required this.l10n,
    required this.payload,
    required this.hint,
    required this.onPaid,
    required this.stripe,
    required this.cash,
  });

  final AppLocalizations l10n;
  final PayPayload payload;
  final String hint;
  final VoidCallback onPaid;
  final bool stripe;
  final bool cash;

  @override
  Widget build(BuildContext context) {
    final border = stripe ? const Color(0xFF635BFF) : Colors.black;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (stripe) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l10n.stripePay,
                style: const TextStyle(
                  color: Color(0xFF635BFF),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.stripeBrands,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          Text(
            cash ? l10n.cashHint : l10n.scanToPay,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (!cash)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 2),
              ),
              child: QrImageView(
                data: payload.text,
                version: QrVersions.auto,
                errorCorrectionLevel: QrErrorCorrectLevel.Q,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(22),
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: stripe ? const Color(0xFF635BFF) : Colors.black,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: stripe ? const Color(0xFF635BFF) : Colors.black,
                ),
                size: 280,
              ),
            ),
          if (!cash) ...[
            const SizedBox(height: 12),
            Text(hint, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: stripe
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF635BFF),
                    )
                  : null,
              onPressed: onPaid,
              child: Text(stripe ? l10n.stripePay : l10n.iPaid),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPane extends StatelessWidget {
  const _StatusPane({
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF8A6A2F)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
