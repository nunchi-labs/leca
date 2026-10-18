import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/app_localizations.dart';
import 'market.dart';
import 'state.dart';

/// Preset tips plus a typed amount. The fare itself is unchanged.
class TipChoices extends StatelessWidget {
  const TipChoices({super.key, this.onChanged});

  final VoidCallback? onChanged;

  static const amounts = <double>[0, 0.5, 1, 2, 5];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.tipTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(l10n.tipHint),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amount in amounts)
              ChoiceChip(
                key: Key('tip_${amount.toStringAsFixed(2)}'),
                label: Text(amount == 0 ? l10n.tipNone : moneyUsd(amount)),
                selected: (state.tipUsd - amount).abs() < 0.001,
                onSelected: (_) {
                  state.setTip(amount);
                  onChanged?.call();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('tip_custom'),
          decoration: InputDecoration(
            labelText: l10n.tipCustom,
            prefixText: r'$',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onSubmitted: (raw) {
            state.setTip(double.tryParse(raw) ?? 0);
            onChanged?.call();
          },
        ),
      ],
    );
  }
}
