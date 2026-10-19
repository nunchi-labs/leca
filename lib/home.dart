import 'dart:async';

import 'package:flutter/material.dart';

import 'account.dart';
import 'art.dart';
import 'book.dart';
import 'catalog.dart';
import 'device.dart';
import 'l10n/app_localizations.dart';
import 'map_screen.dart';
import 'market.dart';
import 'pay.dart';
import 'phone_screen.dart';
import 'reach.dart';
import 'reach_screen.dart';
import 'restaurant.dart';
import 'sale.dart';
import 'shop.dart';
import 'state.dart';
import 'swarm.dart';
import 'talk_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  late Future<List<Kitchen>> _future;

  @override
  void initState() {
    super.initState();
    _future = Catalog.load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !lecaOnPhone(context)) return;
      unawaited(LecaScope.of(context).loadHere());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = Catalog.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = LecaScope.of(context);
    final query = _search.text.trim().toLowerCase();

    if (!lecaOnPhone(context)) {
      return _DeskHome(
        l10n: l10n,
        state: state,
        query: query,
        search: _search,
        future: _future,
        onSearch: () => setState(() {}),
        onReload: _reload,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              children: [
                _Header(l10n: l10n, state: state),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
                  child: Row(
                    children: [
                      Text(
                        _radiusText(l10n, state),
                        key: const Key('search_radius'),
                      ),
                      Expanded(
                        child: Slider(
                          value: state.radiusKm,
                          min: 1,
                          max: LecaState.countryWide,
                          divisions: LecaState.countryWide.toInt() - 1,
                          label: _radiusText(l10n, state),
                          onChanged: state.setRadius,
                        ),
                      ),
                    ],
                  ),
                ),
                _ServiceRow(l10n: l10n),
                const _SuperRail(),
                Expanded(
                  child: FutureBuilder<List<Kitchen>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return _Status(
                          icon: Icons.hourglass_top,
                          title: l10n.loadingPlaces,
                        );
                      }
                      if (snap.hasError) {
                        return _Status(
                          icon: Icons.wifi_off,
                          title: l10n.catalogError,
                          action: l10n.retry,
                          onAction: _reload,
                        );
                      }
                      final kitchens = (snap.data ?? [])
                          .where((k) => state.covers(k.latitude, k.longitude))
                          .where((k) {
                            if (query.isEmpty) return true;
                            final hay =
                                '${k.nameKm} ${k.nameEn} ${k.menu.map((d) => '${d.nameKm} ${d.nameEn}').join(' ')}'
                                    .toLowerCase();
                            return hay.contains(query);
                          })
                          .toList();
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          const _CharterBanner(),
                          const SizedBox(height: 12),
                          Text(
                            l10n.tagline,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.bornInCambodia,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF5C534C)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.feePromise(moneyUsd(0.35)),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: const Color(0xFF5C534C)),
                          ),
                          const SizedBox(height: 16),
                          PopularCard(l10n: l10n, state: state),
                          const SizedBox(height: 16),
                          if (kitchens.isEmpty)
                            _Status(
                              icon: Icons.restaurant_outlined,
                              title: l10n.emptySearchTitle,
                              body: l10n.emptySearchBody,
                            )
                          else
                            ...kitchens.map(
                              (k) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: KitchenTile(
                                  kitchen: k,
                                  l10n: l10n,
                                  lang: state.lang,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            RestaurantScreen(kitchen: k),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ...state.businesses
                              .where(
                                (b) => state.covers(b.latitude, b.longitude),
                              )
                              .where((b) {
                                if (query.isEmpty) return true;
                                return '${b.name} ${b.kind}'
                                    .toLowerCase()
                                    .contains(query);
                              })
                              .map(
                                (b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Card(
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ShopScreen(businessId: b.id),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(b.kind),
                                            const SizedBox(height: 6),
                                            ReplyMark(placeId: b.id),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
                if (state.itemCount > 0)
                  _CartBar(
                    l10n: l10n,
                    state: state,
                    onCheckout: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PayScreen(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeskHome extends StatelessWidget {
  const _DeskHome({
    required this.l10n,
    required this.state,
    required this.query,
    required this.search,
    required this.future,
    required this.onSearch,
    required this.onReload,
  });

  final AppLocalizations l10n;
  final LecaState state;
  final String query;
  final TextEditingController search;
  final Future<List<Kitchen>> future;
  final VoidCallback onSearch;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('desk_home'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _Header(l10n: l10n, state: state),
                Text(
                  l10n.deskLead,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('open_business'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OpenBusinessScreen(),
                    ),
                  ),
                  child: Text(l10n.openBusiness),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ListVehicleScreen(),
                    ),
                  ),
                  child: Text(l10n.listVehicle),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.myBusinesses,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (state.businesses.isEmpty)
                  Text(l10n.emptyBusinesses)
                else
                  for (final business in state.businesses)
                    Card(
                      child: ListTile(
                        title: Text(business.name),
                        subtitle: Text(business.kind),
                        trailing: TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ShopScreen(businessId: business.id),
                            ),
                          ),
                          child: Text(l10n.addItem),
                        ),
                      ),
                    ),
                const SizedBox(height: 24),
                Text(
                  l10n.deskOrder,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(l10n.deliverTo),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButton<String>(
                        key: const Key('deliver_to'),
                        isExpanded: true,
                        value: state.cityId,
                        items: [
                          for (final city in MarketConfig.active.cities)
                            DropdownMenuItem(
                              value: city.id,
                              child: Text(city.nameFor(state.locale)),
                            ),
                        ],
                        onChanged: (id) {
                          if (id != null) state.deliverToCity(id);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      _radiusText(l10n, state),
                      key: const Key('search_radius'),
                    ),
                    Expanded(
                      child: Slider(
                        value: state.radiusKm,
                        min: 1,
                        max: LecaState.countryWide,
                        divisions: LecaState.countryWide.toInt() - 1,
                        label: _radiusText(l10n, state),
                        onChanged: state.setRadius,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: search,
                  onChanged: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ServiceRow(l10n: l10n),
                const _SuperRail(),
                const SizedBox(height: 12),
                const _CharterBanner(),
                const SizedBox(height: 12),
                FutureBuilder<List<Kitchen>>(
                  future: future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return _Status(
                        icon: Icons.hourglass_top,
                        title: l10n.loadingPlaces,
                      );
                    }
                    if (snap.hasError) {
                      return _Status(
                        icon: Icons.wifi_off,
                        title: l10n.catalogError,
                        action: l10n.retry,
                        onAction: onReload,
                      );
                    }
                    final kitchens = (snap.data ?? [])
                        .where((k) => state.covers(k.latitude, k.longitude))
                        .where((k) {
                          if (query.isEmpty) return true;
                          final hay =
                              '${k.nameKm} ${k.nameEn} ${k.menu.map((d) => '${d.nameKm} ${d.nameEn}').join(' ')}'
                                  .toLowerCase();
                          return hay.contains(query);
                        })
                        .toList();
                    if (kitchens.isEmpty) {
                      return _Status(
                        icon: Icons.restaurant_outlined,
                        title: l10n.emptySearchTitle,
                        body: l10n.emptySearchBody,
                      );
                    }
                    return Column(
                      children: [
                        for (final kitchen in kitchens)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: KitchenTile(
                              kitchen: kitchen,
                              l10n: l10n,
                              lang: state.lang,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        RestaurantScreen(kitchen: kitchen),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuperRail extends StatelessWidget {
  const _SuperRail();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Door(
            scene: LecaScene.care,
            km: 'សង្គ្រោះ',
            en: 'Care',
            page: CareScreen(),
          ),
          SizedBox(width: 8),
          _Door(
            scene: LecaScene.fiber,
            km: 'បណ្តាញ',
            en: 'Link',
            page: LinkScreen(),
          ),
          SizedBox(width: 8),
          _Door(
            scene: LecaScene.bus,
            km: 'ធ្វើដំណើរ',
            en: 'Travel',
            page: TravelScreen(),
          ),
          SizedBox(width: 8),
          _Door(
            scene: LecaScene.market,
            km: 'ទិញ',
            en: 'Trade',
            page: TradeScreen(),
          ),
          SizedBox(width: 8),
          _Door(
            scene: LecaScene.seal,
            km: 'ខ្មែរ',
            en: 'Charter',
            page: CharterScreen(),
          ),
          SizedBox(width: 8),
          _Door(
            scene: LecaScene.map,
            km: 'ផែនទី',
            en: 'Map',
            page: MapScreen(),
          ),
        ],
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.scene,
    required this.km,
    required this.en,
    required this.page,
  });

  final LecaScene scene;
  final String km;
  final String en;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: InkWell(
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page));
        },
        child: Column(
          children: [
            const SizedBox(height: 4),
            SizedBox(
              height: 72,
              width: 88,
              child: LecaArt(scene: scene, radius: 12),
            ),
            const SizedBox(height: 4),
            Text(pick(context, km, en), maxLines: 1),
          ],
        ),
      ),
    );
  }
}

class _CharterBanner extends StatelessWidget {
  const _CharterBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: const Key('open_charter'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CharterScreen()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 72,
                height: 72,
                child: LecaArt(scene: LecaScene.seal, radius: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pick(context, 'បានអនុញ្ញាត', 'Cleared'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFB42318),
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      pick(context, 'កម្មវិធីទំនើបខ្មែរ', 'The Khmer superapp'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _radiusText(AppLocalizations l10n, LecaState state) {
  if (state.wholeCountry) return l10n.radiusCountry;
  return l10n.radiusLabel(state.radiusKm.round());
}

class _Header extends StatelessWidget {
  const _Header({required this.l10n, required this.state});

  final AppLocalizations l10n;
  final LecaState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            MarketConfig.brand,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB42318),
            ),
          ),
          IconButton(
            key: const Key('service_care'),
            tooltip: l10n.serviceCare,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CareScreen()),
              );
            },
            icon: const Icon(Icons.local_hospital, color: Color(0xFFB42318)),
          ),
          const Spacer(),
          TextButton(
            onPressed: state.toggleLocale,
            child: Text(l10n.languageToggle),
          ),
          IconButton(
            key: const Key('front_chat'),
            tooltip: l10n.chat,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TalkScreen(
                    room: frontRoom,
                    title: l10n.chat,
                    fareKey: frontFare,
                    onCheckout: () {
                      final live = LecaScope.of(context);
                      final usd = live.payable(frontFare, 0);
                      if (usd <= 0) return;
                      live.setBooking(
                        Booking(
                          kind: BookKind.goods,
                          title: l10n.chat,
                          amountUsd: usd,
                          detail: frontRoom,
                        ),
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PayScreen(),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            key: const Key('account_button'),
            tooltip: l10n.accountTitle,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
              );
            },
            icon: Icon(
              state.driving ? Icons.directions_car : Icons.person_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _ServiceChip(
              key: const Key('service_phone'),
              label: l10n.servicePhone,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(label: l10n.serviceFood, selected: true, onTap: () {}),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_moto'),
              label: l10n.serviceMoto,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookScreen(
                    kind: BookKind.ride,
                    vehicleId: 'motorcycle',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              label: l10n.serviceRides,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookScreen(kind: BookKind.ride),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              label: l10n.serviceRent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookScreen(kind: BookKind.rent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_sale'),
              label: l10n.serviceSale,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VehicleSaleScreen(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              label: l10n.serviceSend,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BookScreen(kind: BookKind.send),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_link'),
              label: l10n.serviceLink,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LinkScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_travel'),
              label: l10n.serviceTravel,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TravelScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_trade'),
              label: l10n.serviceTrade,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TradeScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_charter'),
              label: l10n.serviceCharter,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CharterScreen()),
              ),
            ),
            const SizedBox(width: 8),
            _ServiceChip(
              key: const Key('service_map'),
              label: l10n.serviceMap,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const MapScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFB42318) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF1A1410),
            ),
          ),
        ),
      ),
    );
  }
}

class PopularCard extends StatelessWidget {
  const PopularCard({super.key, required this.l10n, required this.state});

  final AppLocalizations l10n;
  final LecaState state;

  @override
  Widget build(BuildContext context) {
    final nearby = Catalog.kitchens
        .where((k) => state.covers(k.latitude, k.longitude))
        .map((k) => k.id);
    final pick = Catalog.popularNear(nearby, state.window);
    Kitchen? kitchen;
    Dish? dish;
    if (pick != null) {
      kitchen = Catalog.kitchen(pick.kitchenId);
      dish = kitchen.dish(pick.dishId);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              state.wholeCountry
                  ? l10n.popularCountry
                  : l10n.popularTitle(state.radiusKm.round()),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in PopularWindow.values)
                  ChoiceChip(
                    label: Text(_windowLabel(l10n, w)),
                    selected: state.window == w,
                    onSelected: (_) => state.setWindow(w),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (pick == null || kitchen == null || dish == null)
              Text(l10n.popularEmpty)
            else
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RestaurantScreen(kitchen: kitchen!),
                    ),
                  );
                },
                child: Row(
                  children: [
                    const Icon(Icons.whatshot, color: Color(0xFFB42318)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.nameFor(state.lang),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${kitchen.nameFor(state.lang)} · ${l10n.popularOrders(pick.orders)}',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _windowLabel(AppLocalizations l10n, PopularWindow w) {
    switch (w) {
      case PopularWindow.hour:
        return l10n.windowHour;
      case PopularWindow.day:
        return l10n.windowDay;
      case PopularWindow.week:
        return l10n.windowWeek;
      case PopularWindow.month:
        return l10n.windowMonth;
    }
  }
}

class KitchenTile extends StatelessWidget {
  const KitchenTile({
    super.key,
    required this.kitchen,
    required this.l10n,
    required this.lang,
    required this.onTap,
  });

  final Kitchen kitchen;
  final AppLocalizations l10n;
  final LocaleCode lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const LecaArt(scene: LecaScene.bowl, radius: 26),
                    Text(
                      _initial(kitchen.nameFor(lang)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kitchen.nameFor(lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${kitchen.areaFor(lang)} · ${l10n.etaMins(kitchen.etaMin)} · ${l10n.deliveryFrom(moneyUsd(LecaScope.of(context).deliveryQuoteOf(kitchen).usd))}',
                    ),
                    const SizedBox(height: 6),
                    ReplyMark(placeId: kitchen.id),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.chat,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        placeId: kitchen.id,
                        title: kitchen.nameFor(lang),
                        fareKey: LecaScope.of(context).deliveryFareKey(kitchen),
                        appUsd: LecaScope.of(context)
                            .deliveryQuoteOf(kitchen)
                            .usd,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
              ),
              Text(
                kitchen.rating.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({
    required this.l10n,
    required this.state,
    required this.onCheckout,
  });

  final AppLocalizations l10n;
  final LecaState state;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1410),
      child: InkWell(
        onTap: onCheckout,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
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
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 36, color: const Color(0xFF8A6A2F)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, textAlign: TextAlign.center),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}

String _initial(String name) {
  final it = name.runes.iterator;
  if (!it.moveNext()) return '?';
  return String.fromCharCode(it.current);
}
