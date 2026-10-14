import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'market.dart';
import 'state.dart';

/// The calculated fare stays in force until the other side allows a new one.
/// A driver may ask for more. A customer may offer less. Either way the
/// other side has to allow it before it is charged.
class FareNegotiate extends StatefulWidget {
  const FareNegotiate({
    super.key,
    required this.fareKey,
    required this.appUsd,
    this.onProposed,
    this.onAllowed,
  });

  final String fareKey;
  final double appUsd;

  /// Called after a local ask so a chat can carry it to the other side.
  final void Function(double usd, String proposer)? onProposed;
  final void Function(double usd)? onAllowed;

  @override
  State<FareNegotiate> createState() => _FareNegotiateState();
}

class _FareNegotiateState extends State<FareNegotiate> {
  final _ask = TextEditingController();

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    final ask = state.fareAsk;
    final mine = ask != null && ask.key == widget.fareKey;
    final waiting = mine && !ask.allowed;
    final agreed = mine && ask.allowed;
    final side = state.fareSide;
    final who = side == 'driver' ? l10n.whoDriver : l10n.whoCustomer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (agreed) Text('${l10n.appPrice}  ${moneyUsd(widget.appUsd)}'),
        if (mine)
          Text(
            l10n.proposedBy(
              ask.proposer == 'driver' ? l10n.whoDriver : l10n.whoCustomer,
              moneyUsd(ask.askUsd),
            ),
            key: Key('fare_ask_${widget.fareKey}'),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: TextField(
                key: Key('fare_field_${widget.fareKey}'),
                controller: _ask,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.yourPrice(who),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            OutlinedButton(
              key: Key('fare_propose_${widget.fareKey}'),
              onPressed: () {
                final parsed = double.tryParse(_ask.text.trim());
                if (parsed == null || parsed <= 0) return;
                state.proposeFare(
                  widget.fareKey,
                  widget.appUsd,
                  parsed,
                  proposer: side,
                );
                widget.onProposed?.call(parsed, side);
              },
              child: Text(l10n.proposeFare),
            ),
            if (waiting)
              FilledButton.tonal(
                key: Key('fare_allow_${widget.fareKey}'),
                onPressed: () {
                  state.allowFare();
                  widget.onAllowed?.call(ask.askUsd);
                },
                child: Text(l10n.allowFare),
              ),
          ],
        ),
        if (waiting)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.fareWaiting),
          ),
      ],
    );
  }
}
