import 'package:flutter/material.dart';

import 'compliance.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'pay.dart';
import 'state.dart';

/// Motorcycles, cars, tuk-tuks, and remorques an owner has put up for sale.
class VehicleSaleScreen extends StatefulWidget {
  const VehicleSaleScreen({super.key});

  @override
  State<VehicleSaleScreen> createState() => _VehicleSaleScreenState();
}

class _VehicleSaleScreenState extends State<VehicleSaleScreen> {
  String _kind = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final listed = state.sales
        .where((sale) => state.covers(sale.latitude, sale.longitude))
        .where((sale) => _kind.isEmpty || sale.kind == _kind)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.saleTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                state.wholeCountry
                    ? l10n.radiusCountry
                    : l10n.radiusLabel(state.radiusKm.round()),
              ),
              const SizedBox(height: 8),
              Text(l10n.saleBody),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('open_sale_form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SellVehicleScreen(),
                    ),
                  );
                },
                child: Text(l10n.sellVehicle),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const Key('sale_filter_all'),
                    label: Text(l10n.saleKindAll),
                    selected: _kind.isEmpty,
                    onSelected: (_) => setState(() => _kind = ''),
                  ),
                  for (final kind in CambodiaRules.saleKinds)
                    ChoiceChip(
                      key: Key('sale_filter_$kind'),
                      label: Text(_kindLabel(l10n, kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (listed.isEmpty)
                Text(l10n.saleEmpty)
              else
                for (final sale in listed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sale.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(_kindLabel(l10n, sale.kind)),
                          if (sale.note.isNotEmpty) Text(sale.note),
                          const SizedBox(height: 4),
                          Text(
                            '${moneyUsd(sale.usd)} · ${moneyKhr(sale.usd)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (sale.sellerName.isNotEmpty)
                            Text(
                              l10n.sellerLine(
                                sale.sellerName,
                                sale.sellerPhone,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              FilledButton(
                                key: Key('buy_${sale.id}'),
                                onPressed: () {
                                  state.setBooking(
                                    Booking(
                                      kind: BookKind.goods,
                                      title: sale.title,
                                      amountUsd: sale.usd,
                                      detail: sale.kind,
                                      vehicleId: sale.kind,
                                    ),
                                  );
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const PayScreen(),
                                    ),
                                  );
                                },
                                child: Text(l10n.buyVehicle),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                key: Key('remove_${sale.id}'),
                                onPressed: () => state.removeSale(sale.id),
                                child: Text(l10n.removeSale),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class SellVehicleScreen extends StatefulWidget {
  const SellVehicleScreen({super.key});

  @override
  State<SellVehicleScreen> createState() => _SellVehicleScreenState();
}

class _SellVehicleScreenState extends State<SellVehicleScreen> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _price = TextEditingController();
  final _sellerName = TextEditingController();
  final _sellerPhone = TextEditingController();
  final _sellerId = TextEditingController();
  String _kind = 'motorcycle';
  bool _owner = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _price.dispose();
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
      appBar: AppBar(title: Text(l10n.sellVehicle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.saleBody),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in CambodiaRules.saleKinds)
                    ChoiceChip(
                      key: Key('sale_kind_$kind'),
                      label: Text(_kindLabel(l10n, kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ActionChip(
                key: const Key('sale_example_adv'),
                label: const Text('Honda ADV 350'),
                onPressed: () {
                  setState(() {
                    _kind = 'motorcycle';
                    _title.text = 'Honda ADV 350';
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale_title'),
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.saleTitleLabel,
                  hintText: l10n.saleTitleHint,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale_note'),
                controller: _note,
                decoration: InputDecoration(
                  labelText: l10n.itemDescriptionKm,
                  hintText: l10n.saleNoteHint,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale_price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.itemPrice,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale_seller_name'),
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
                key: const Key('sale_seller_phone'),
                controller: _sellerPhone,
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
                key: const Key('sale_seller_id'),
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
              CheckboxListTile(
                key: const Key('sale_owner'),
                contentPadding: EdgeInsets.zero,
                value: _owner,
                title: Text(l10n.ownerConfirm),
                onChanged: (value) => setState(() => _owner = value ?? false),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _saleError(l10n, _error!),
                    style: const TextStyle(color: Color(0xFF8B1E1E)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_sale'),
                onPressed: () {
                  final code = state.listSale(
                    kind: _kind,
                    title: _title.text,
                    note: _note.text,
                    usd: double.tryParse(_price.text.trim()) ?? 0,
                    owner: _owner,
                    sellerName: _sellerName.text,
                    sellerPhone: _sellerPhone.text,
                    sellerId: _sellerId.text,
                  );
                  if (code != null) {
                    setState(() => _error = code);
                    return;
                  }
                  Navigator.pop(context);
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

String _kindLabel(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'motorcycle':
      return l10n.saleKindMotorcycle;
    case 'car':
      return l10n.saleKindCar;
    case 'tuktuk':
      return l10n.saleKindTuktuk;
    case 'remorque':
      return l10n.saleKindRemorque;
    default:
      return kind;
  }
}

String _saleError(AppLocalizations l10n, String code) {
  switch (code) {
    case 'sale_kind':
      return l10n.saleKindInvalid;
    case 'owner_required':
      return l10n.ownerRequired;
    case 'seller_kyc':
      return l10n.sellerKycInvalid;
    case 'item_khmer':
      return l10n.itemKhmer;
    default:
      return l10n.saleInvalid;
  }
}
