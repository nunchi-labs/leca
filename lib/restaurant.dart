import 'package:flutter/material.dart';

import 'catalog.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'negotiate.dart';
import 'pay.dart';
import 'shop.dart';
import 'state.dart';

class RestaurantScreen extends StatelessWidget {
  const RestaurantScreen({super.key, required this.kitchen});

  final Kitchen kitchen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    final menu = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: kitchen.menu.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final dish = kitchen.menu[i];
        final count = state.countOf(dish.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.nameFor(state.lang),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.lang == LocaleCode.km
                            ? dish.detailKm
                            : dish.detailEn,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${moneyUsd(dish.usd)} · ${moneyKhr(dish.usd)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (count == 0)
                  FilledButton(
                    onPressed: () => state.addDish(dish, kitchen),
                    child: Text(l10n.add),
                  )
                else
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => state.removeDish(dish),
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$count',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () => state.addDish(dish, kitchen),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );

    final cart = state.itemCount > 0 && state.cartKitchen?.id == kitchen.id
        ? Material(
            color: const Color(0xFF1A1410),
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PayScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Text(
                      '${l10n.cartItems(state.itemCount)} · ${moneyUsd(state.totalUsd)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      l10n.checkout,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(kitchen.nameFor(state.lang)),
        actions: [
          IconButton(
            tooltip: l10n.chat,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    placeId: kitchen.id,
                    title: kitchen.nameFor(state.lang),
                    fareKey: state.deliveryFareKey(kitchen),
                    appUsd: state.deliveryQuoteOf(kitchen).usd,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${kitchen.areaFor(state.lang)} · ${l10n.etaMins(kitchen.etaMin)} · ${l10n.deliveryFrom(moneyUsd(state.deliveryQuoteOf(kitchen).usd))}',
                      ),
                      const SizedBox(height: 6),
                      ReplyMark(placeId: kitchen.id),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 3, child: menu),
                          if (cart != null)
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: _CheckoutSummary(
                                  l10n: l10n,
                                  state: state,
                                  onPay: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const PayScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      )
                    : menu,
              ),
              if (!wide && cart != null) cart,
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.l10n,
    required this.state,
    required this.onPay,
  });

  final AppLocalizations l10n;
  final ChowState state;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.cart,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text('${l10n.subtotal}  ${moneyUsd(state.subtotalUsd)}'),
            if (state.cartKitchen != null) ...[
              Text(
                '${l10n.deliveryFee}  ${moneyUsd(state.deliveryQuoteOf(state.cartKitchen!).usd)}',
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
              FareNegotiate(
                fareKey: state.deliveryFareKey(state.cartKitchen!),
                appUsd: state.deliveryQuoteOf(state.cartKitchen!).usd,
              ),
            ],
            Text('${l10n.serviceFee}  ${moneyUsd(state.feeUsd)}'),
            const SizedBox(height: 8),
            Text(
              '${l10n.total}  ${moneyUsd(state.totalUsd)} · ${moneyKhr(state.totalUsd)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPay, child: Text(l10n.checkout)),
          ],
        ),
      ),
    );
  }
}
