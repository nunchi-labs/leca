import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'market.dart';
import 'records.dart';
import 'state.dart';

/// The calculated fare stays in force until the other side allows a bid.
/// A driver may ask for more. A customer may offer less. Either side may
/// counter as many times as they like, until one of them ends it.
class FareNegotiate extends StatefulWidget {
  const FareNegotiate({
    super.key,
    required this.fareKey,
    required this.appUsd,
    this.onProposed,
    this.onAllowed,
    this.onEnded,
  });

  final String fareKey;
  final double appUsd;

  /// Called after a local bid so a chat can carry it to the other side.
  final void Function(double usd, String side)? onProposed;
  final void Function(double usd)? onAllowed;
  final void Function()? onEnded;

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

  String _who(AppLocalizations l10n, String side) =>
      side == 'driver' ? l10n.whoDriver : l10n.whoCustomer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    final ask = state.askFor(widget.fareKey);
    final side = state.fareSide;
    final pending = ask?.open == true ? ask!.pending : null;
    final theirs = pending != null && pending.side != side;
    final mine = pending != null && pending.side == side;
    final agreed = ask?.agreedUsd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ask != null && ask.bids.isNotEmpty) ...[
          for (final bid in ask.bids)
            Text(
              '${_who(l10n, bid.side)}  ${moneyUsd(bid.usd)}',
              style: TextStyle(
                color: identical(bid, ask.bids.last)
                    ? null
                    : const Color(0x991A1410),
              ),
            ),
          const SizedBox(height: 4),
        ],
        if (agreed != null)
          Text(
            '${l10n.agreedPrice}  ${moneyUsd(agreed)}',
            key: Key('fare_agreed_${widget.fareKey}'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        if (pending != null)
          Text(
            l10n.proposedBy(_who(l10n, pending.side), moneyUsd(pending.usd)),
            key: Key('fare_ask_${widget.fareKey}'),
          ),
        if (ask?.ended == true)
          Text(
            l10n.fareEnded(moneyUsd(ask!.usd)),
            key: Key('fare_ended_${widget.fareKey}'),
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
                  labelText: l10n.yourPrice(_who(l10n, side)),
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
                _ask.clear();
                widget.onProposed?.call(parsed, side);
              },
              child: Text(theirs ? l10n.counterFare : l10n.proposeFare),
            ),
            if (theirs)
              FilledButton.tonal(
                key: Key('fare_allow_${widget.fareKey}'),
                onPressed: () {
                  state.allowFare(widget.fareKey);
                  widget.onAllowed?.call(pending.usd);
                },
                child: Text(l10n.allowFare),
              ),
            if (ask != null && !ask.ended)
              TextButton(
                key: Key('fare_end_${widget.fareKey}'),
                onPressed: () {
                  state.endFare(widget.fareKey);
                  widget.onEnded?.call();
                },
                child: Text(l10n.endFare),
              ),
          ],
        ),
        if (mine)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.fareWaiting),
          ),
        if (theirs)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(l10n.fareYourTurn),
          ),
      ],
    );
  }
}

/// Short, readable label for a bargain's state. Used beside prices.
String fareLabel(AppLocalizations l10n, FareAsk? ask) {
  if (ask?.agreedUsd != null) return l10n.agreedPrice;
  return l10n.appPrice;
}
