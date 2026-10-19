import 'package:flutter/material.dart';

import 'reach.dart';

/// One, or a typed extreme. [max] keeps an ambulance incident small.
class QtyBar extends StatefulWidget {
  const QtyBar({required this.onChanged, super.key, this.max = maxBulk});

  final ValueChanged<int> onChanged;
  final int max;

  @override
  State<QtyBar> createState() => _QtyBarState();
}

class _QtyBarState extends State<QtyBar> {
  final _field = TextEditingController(text: '1');
  int _qty = 1;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply(int n, {required bool fromField}) {
    final next = clampQty(n, max: widget.max);
    final label = '$next';
    final rewrite = !fromField || next != n;
    if (rewrite && _field.text != label) {
      _field.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
    }
    if (next == _qty) return;
    setState(() => _qty = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    const steps = <int>[1, 10, 100, 1000, 10000, 100000];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final step in steps)
              if (step <= widget.max)
                ChoiceChip(
                  label: Text('$step'),
                  selected: _qty == step,
                  onSelected: (_) => _apply(step, fromField: false),
                ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('qty_field'),
          controller: _field,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: pick(context, 'ចំនួន', 'Quantity'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            final n = int.tryParse(value.trim());
            if (n == null) return;
            _apply(n, fromField: true);
          },
        ),
      ],
    );
  }
}
