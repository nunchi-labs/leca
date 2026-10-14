import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'identity.dart';
import 'talk_screen.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'pay.dart';
import 'rate.dart';
import 'state.dart';

class ReplyMark extends StatelessWidget {
  const ReplyMark({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final seconds = state.replySecondsFor(placeId);
    final hours = state.hoursFor(placeId);
    final color = seconds == null
        ? const Color(0xFF8A6A2F)
        : repliesFast(seconds)
        ? const Color(0xFF1B7F3A)
        : const Color(0xFFB42318);
    final label = seconds == null
        ? l10n.replyNew
        : repliesFast(seconds)
        ? l10n.replyFast
        : l10n.replySlow;
    final open = hours.$1.toString().padLeft(2, '0');
    final close = hours.$2.toString().padLeft(2, '0');
    final timing = seconds == null
        ? ''
        : ' · ${l10n.etaMins((seconds / 60).ceil())}';
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text('$label$timing · ${l10n.workingHours(open, close)}'),
        ),
      ],
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.businessId});

  final String businessId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final matches = state.businesses.where((b) => b.id == businessId).toList();
    if (matches.isEmpty) {
      return Scaffold(appBar: AppBar(title: Text(l10n.shopTitle)));
    }
    final business = matches.first;
    final goods = state.itemsFor(business.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(business.name),
        actions: [
          IconButton(
            tooltip: l10n.chat,
            onPressed: () => _openChat(context, business.id, business.name),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text('${business.kind} · ${business.cityId}'),
              if (business.sellerName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.sellerLine(business.sellerName, business.sellerPhone),
                ),
              ],
              const SizedBox(height: 8),
              Text(l10n.payMethods),
              const SizedBox(height: 8),
              ReplyMark(placeId: business.id),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('consumer_report'),
                onPressed: () => _complain(context, state, business.id),
                child: Text(l10n.consumerReport),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('add_item'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AddItemScreen(businessId: business.id),
                    ),
                  );
                },
                child: Text(l10n.addItem),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _openChat(context, business.id, business.name),
                child: Text(l10n.chat),
              ),
              const SizedBox(height: 16),
              if (goods.isEmpty)
                Text(l10n.emptyItems)
              else
                for (final item in goods)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              item.photo,
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
                                Text(item.description),
                                Text(
                                  '${moneyUsd(item.usd)} · ${moneyKhr(item.usd)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton(
                                  key: Key('takedown_${item.id}'),
                                  onPressed: () {
                                    state.takeDownItem(item.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n.takedownDone),
                                      ),
                                    );
                                  },
                                  child: Text(l10n.takedown),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              state.setBooking(
                                Booking(
                                  kind: BookKind.goods,
                                  title: item.description,
                                  amountUsd: item.usd,
                                  detail: item.id,
                                ),
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const PayScreen(),
                                ),
                              );
                            },
                            child: Text(l10n.checkout),
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

  Future<void> _complain(
    BuildContext context,
    LecaState state,
    String businessId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final note = TextEditingController();
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.consumerReport),
          content: TextField(
            controller: note,
            decoration: InputDecoration(hintText: l10n.noteHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.consumerReport),
            ),
          ],
        );
      },
    );
    final body = note.text;
    note.dispose();
    if (sent != true || !context.mounted) return;
    state.fileConsumerReport(businessId, body);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.consumerReportDone)));
  }

  void _openChat(BuildContext context, String id, String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(placeId: id, title: title),
      ),
    );
  }
}

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.businessId});

  final String businessId;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _description = TextEditingController();
  final _price = TextEditingController();
  Uint8List? _photo;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addItem)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () async {
                    final bytes = await PhotoPick.image();
                    if (!mounted || bytes == null) return;
                    setState(() => _photo = bytes);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x1A1A1410)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photo == null
                        ? Text(l10n.pickPhoto)
                        : Image.memory(
                            _photo!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: l10n.itemDescriptionKm,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error == 'item_khmer' ? l10n.itemKhmer : l10n.itemInvalid,
                    style: const TextStyle(color: Color(0xFF8B1E1E)),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_item'),
                onPressed: () {
                  final code = state.addItem(
                    businessId: widget.businessId,
                    description: _description.text,
                    usd: double.tryParse(_price.text.trim()) ?? 0,
                    photo: _photo,
                  );
                  if (code != null) {
                    setState(() => _error = code);
                    return;
                  }
                  Navigator.pop(context);
                },
                child: Text(l10n.saveItem),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.placeId,
    required this.title,
    this.fareKey,
    this.appUsd = 0,
  });

  final String placeId;
  final String title;
  final String? fareKey;
  final double appUsd;

  @override
  Widget build(BuildContext context) {
    return TalkScreen(
      room: placeId,
      title: title,
      header: ReplyMark(placeId: placeId),
      fareKey: fareKey,
      appUsd: appUsd,
    );
  }
}
