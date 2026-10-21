import 'dart:async';

import 'package:flutter/material.dart';

import 'art.dart';
import 'device.dart';
import 'market.dart';
import 'pay.dart';
import 'phone_screen.dart';
import 'qty.dart';
import 'reach.dart';
import 'state.dart';

void _pay(BuildContext context, Booking booking) {
  LecaScope.of(context).setBooking(booking);
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const PayScreen()));
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: children,
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.scene, required this.caption});

  final LecaScene scene;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          width: double.infinity,
          child: LecaArt(scene: scene),
        ),
        const SizedBox(height: 8),
        Text(caption),
      ],
    );
  }
}

class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});

  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final _search = TextEditingController();
  String _plan = mobilePlans.first.id;
  int _lines = 1;
  int _fiberQty = 1;
  int _hotQty = 1;
  String? _city;
  String? _on;
  int _reading = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final city = LecaScope.of(context).cityId;
    if (city == _city && _on != null) return;
    _city = city;
    _on = multiNet(city, reading: _reading, carrying: _on).carrying;
  }

  void _recheck() {
    final city = LecaScope.of(context).cityId;
    final before = _on;
    _reading += 1;
    final next = multiNet(city, reading: _reading, carrying: before).carrying;
    setState(() => _on = next);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    final plan = mobilePlans.firstWhere((item) => item.id == _plan);
    final net = multiNet(state.cityId, reading: _reading, carrying: _on);
    final paces = net.live;
    final hostId = net.carrying;
    final host = hostNets.firstWhere((item) => item.id == hostId);
    final issued = issueLines(
      planId: plan.id,
      unitUsd: plan.usd,
      count: _lines,
    );
    final query = _search.text.trim().toLowerCase();
    final plans = [
      for (final item in fiberPlans)
        if (query.isEmpty ||
            item.brand.toLowerCase().contains(query) ||
            item.brandKm.toLowerCase().contains(query))
          item,
    ];
    return _Page(
      title: pick(context, 'ទូរស័ព្ទ និងបណ្តាញ', 'Mobile and internet'),
      children: [
        _Hero(
          scene: LecaScene.fiber,
          caption: pick(
            context,
            'Leca ផ្តល់ស៊ីម។ សំឡេងឥតគិតថ្លៃលើ $userComms។ បណ្តាញទាំងបួននៅផ្ទាល់។ ទិន្នន័យប្រើបណ្តាញលឿនបំផុត។',
            'Leca provisions the SIM. Voice is free on $userComms. All four networks stay live. Data uses the fastest.',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: LecaArt(scene: LecaScene.call, radius: 16),
        ),
        const SizedBox(height: 16),
        Text(
          pick(context, 'ខ្សែទូរស័ព្ទ', 'Mobile line'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          pick(
            context,
            '${hostNets.length} បណ្តាញផ្ទាល់។ ទិន្នន័យនៅលើ ${host.nameKm}។',
            '${hostNets.length} networks live. Data is on ${host.nameEn}.',
          ),
          key: const Key('sim_on'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final pace in paces)
          ListTile(
            key: Key('pace_${pace.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              hostNets
                  .firstWhere((item) => item.id == pace.id)
                  .nameFor(context),
            ),
            subtitle: Text('${pace.mbps.round()} Mbps'),
            trailing: Text(
              pace.id == hostId
                  ? pick(context, 'ទិន្នន័យ', 'Data')
                  : pick(context, 'ផ្ទាល់', 'Live'),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('sim_recheck'),
            onPressed: _recheck,
            child: Text(
              pick(context, 'វាស់ម្តងទៀត', 'Read the networks again'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final item in mobilePlans)
              ChoiceChip(
                label: Text('${item.nameFor(context)} · ${moneyUsd(item.usd)}'),
                selected: _plan == item.id,
                onSelected: (_) => setState(() => _plan = item.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          pick(
            context,
            'សំឡេង ${moneyUsd(plan.voiceUsd)} · ${plan.dataGb == 0 ? "ទិន្នន័យមិនកំណត់" : "${plan.dataGb} GB"}',
            'Voice ${moneyUsd(plan.voiceUsd)} · ${plan.dataGb == 0 ? "unmetered data" : "${plan.dataGb} GB"}',
          ),
        ),
        const SizedBox(height: 8),
        QtyBar(onChanged: (n) => setState(() => _lines = n)),
        const SizedBox(height: 8),
        Text('${issued.first} → ${issued.last} · ${issued.count}'),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('provision_line'),
          onPressed: () => _pay(
            context,
            Booking(
              kind: BookKind.goods,
              title: '${plan.nameFor(context)} · ${host.nameFor(context)}',
              amountUsd: issued.usd,
              detail:
                  'mvno:${plan.id}:multi:${host.id} ${issued.first}..${issued.last} x${issued.count}',
            ),
          ),
          child: Text(
            '${pick(context, 'ផ្តល់ខ្សែ', 'Provision')} · ${moneyUsd(issued.usd)}',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          pick(context, 'ហតស្ប៉ត 5G+ សម្រាប់ផ្ទះ', '5G+ hotspots for home'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        QtyBar(onChanged: (n) => setState(() => _hotQty = n)),
        for (final spot in homeHotspots)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(spot.nameFor(context)),
            subtitle: Text('${spot.mobile} · ${moneyUsd(spot.usd)}'),
            trailing: Text(moneyUsd(bulkUsd(spot.usd, _hotQty))),
            onTap: () => _pay(
              context,
              Booking(
                kind: BookKind.goods,
                title: '${spot.nameFor(context)} × $_hotQty',
                amountUsd: bulkUsd(spot.usd, _hotQty),
                detail: 'hotspot:${spot.id} x$_hotQty',
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          pick(
            context,
            'ខ្សែកាប ១០ ជីកា គ្រប់ទីប្រជាជន',
            '10 Gbps fiber and cable, every populated center',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('fiber_search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: pick(context, 'ស្វែងរកប្រតិបត្តិករ', 'Search operators'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        QtyBar(onChanged: (n) => setState(() => _fiberQty = n)),
        Text(pick(context, '${plans.length} ប្រភេទ', '${plans.length} kinds')),
        for (final item in plans)
          ListTile(
            key: Key('fiber_${item.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(item.nameFor(context)),
            subtitle: Text(
              '${item.gbps} Gbps · ${item.medium == Medium.cable ? pick(context, 'ខ្សែកាប', 'Cable') : pick(context, 'អុបទិក', 'Fiber')} · ${moneyUsd(item.usd)}',
            ),
            trailing: Text(moneyUsd(bulkUsd(item.usd, _fiberQty))),
            onTap: () => _pay(
              context,
              Booking(
                kind: BookKind.goods,
                title: '${item.nameFor(context)} × $_fiberQty',
                amountUsd: bulkUsd(item.usd, _fiberQty),
                detail: 'fiber:${item.id} x$_fiberQty',
              ),
            ),
          ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: Text(
            populatedSaturated
                ? pick(
                    context,
                    '${populatedTowns.length} ទីប្រជាជន · 10 Gbps · 5G+',
                    '${populatedTowns.length} populated centers · 10 Gbps · 5G+',
                  )
                : pick(context, 'គ្របដណ្តប់', 'Coverage'),
          ),
          children: [
            for (final town in populatedTowns)
              ListTile(
                dense: true,
                title: Text(
                  state.locale.languageCode == 'km'
                      ? MarketConfig.active.city(town.cityId).nameKm
                      : MarketConfig.active.city(town.cityId).nameEn,
                ),
                subtitle: Text('${town.fiberGbps} Gbps · ${town.mobile}'),
              ),
          ],
        ),
      ],
    );
  }
}

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  String _from = 'phnom_penh';
  String _to = 'siem_reap';
  int _seats = 1;

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    final hops = passagesBetween(_from, _to);
    return _Page(
      title: pick(context, 'ឡានក្រុង និងយន្តហោះ', 'Bus and air'),
      children: [
        const Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 120,
                child: LecaArt(scene: LecaScene.bus),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 120,
                child: LecaArt(scene: LecaScene.air),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          pick(
            context,
            'សំបុត្ររបស់ប្រតិបត្តិករ។ Leca មិនបើកឡានក្រុង ឬយន្តហោះទេ។ មួយកៅអី ឬទាំងក្រុម។',
            'Tickets for the operator. Leca does not run the coach or the aircraft. One seat, or a whole group.',
          ),
        ),
        const SizedBox(height: 12),
        _CityMenu(
          label: pick(context, 'ចេញ', 'From'),
          value: _from,
          locale: state.locale,
          onChanged: (id) => setState(() => _from = id),
        ),
        _CityMenu(
          label: pick(context, 'ទៅ', 'To'),
          value: _to,
          locale: state.locale,
          onChanged: (id) => setState(() => _to = id),
        ),
        const SizedBox(height: 8),
        QtyBar(onChanged: (n) => setState(() => _seats = n)),
        if (hops.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              pick(
                context,
                'មិនទាន់មានសំបុត្រផ្លូវនេះ។',
                'No ticket on this route yet.',
              ),
            ),
          )
        else
          for (final hop in hops)
            ListTile(
              key: Key('hop_${hop.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                hop.way == Way.air ? Icons.flight : Icons.directions_bus,
              ),
              title: Text(hop.operatorFor(context)),
              subtitle: Text(
                '${clock(context, hop.minutes)} · ${moneyUsd(hop.usd)}',
              ),
              trailing: Text(moneyUsd(bulkUsd(hop.usd, _seats))),
              onTap: () => _pay(
                context,
                Booking(
                  kind: BookKind.goods,
                  title: '${hop.operatorFor(context)} × $_seats',
                  amountUsd: bulkUsd(hop.usd, _seats),
                  detail: '${hop.way.name}:${hop.id} x$_seats',
                ),
              ),
            ),
      ],
    );
  }
}

class _CityMenu extends StatelessWidget {
  const _CityMenu({
    required this.label,
    required this.value,
    required this.locale,
    required this.onChanged,
  });

  final String label;
  final String value;
  final Locale locale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            items: [
              for (final city in MarketConfig.active.cities)
                DropdownMenuItem(
                  value: city.id,
                  child: Text(city.nameFor(locale)),
                ),
            ],
            onChanged: (id) {
              if (id != null) onChanged(id);
            },
          ),
        ),
      ],
    );
  }
}

class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  final _search = TextEditingController();
  String _buyer = 'phnom_penh';
  var _buyerSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_buyerSet) return;
    _buyerSet = true;
    _buyer = LecaScope.of(context).cityId;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final goods = [
      for (final good in shelf)
        if (query.isEmpty ||
            '${good.titleEn} ${good.titleKm} ${good.sellerEn} ${good.sellerKm}'
                .toLowerCase()
                .contains(query))
          good,
    ];
    return _Page(
      title: pick(context, 'គ្រប់ទីកន្លែង', 'Anywhere'),
      children: [
        const _Hero(scene: LecaScene.market, caption: ''),
        Text(
          pick(
            context,
            'អ្នកណាក៏បាន គ្រប់ខេត្ត ទិញពីអ្នកណាក៏បាននៅខេត្តផ្សេង។ ចម្ងាយមិនបិទការទិញ។',
            'Anyone, in any province, can buy from anyone in any other. Distance does not close the sale.',
          ),
        ),
        const SizedBox(height: 12),
        _CityMenu(
          label: pick(context, 'ខ្ញុំនៅ', 'I am in'),
          value: _buyer,
          locale: state.locale,
          onChanged: (id) => setState(() => _buyer = id),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: pick(context, 'ស្វែងរកទំនិញ', 'Search goods'),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        for (final good in goods) _GoodTile(good: good, buyerCity: _buyer),
        for (final item in state.items)
          if (!item.removed)
            _ShelfTile(
              title: item.description,
              seller: _sellerName(state, item.businessId),
              cityId: _sellerCity(state, item.businessId),
              usd: item.usd,
              buyerCity: _buyer,
              detail: 'shop:${item.id}',
            ),
      ],
    );
  }

  String _sellerName(LecaState state, String businessId) {
    for (final business in state.businesses) {
      if (business.id == businessId) return business.name;
    }
    return '';
  }

  String _sellerCity(LecaState state, String businessId) {
    for (final business in state.businesses) {
      if (business.id == businessId) return business.cityId;
    }
    return state.cityId;
  }
}

class _GoodTile extends StatelessWidget {
  const _GoodTile({required this.good, required this.buyerCity});

  final ShelfGood good;
  final String buyerCity;

  @override
  Widget build(BuildContext context) {
    return _ShelfTile(
      title: good.titleFor(context),
      seller: good.sellerFor(context),
      cityId: good.cityId,
      usd: good.usd,
      buyerCity: buyerCity,
      detail: 'shelf:${good.id}',
    );
  }
}

class _ShelfTile extends StatefulWidget {
  const _ShelfTile({
    required this.title,
    required this.seller,
    required this.cityId,
    required this.usd,
    required this.buyerCity,
    required this.detail,
  });

  final String title;
  final String seller;
  final String cityId;
  final double usd;
  final String buyerCity;
  final String detail;

  @override
  State<_ShelfTile> createState() => _ShelfTileState();
}

class _ShelfTileState extends State<_ShelfTile> {
  int _qty = 1;
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final ship = shipBetween(widget.cityId, widget.buyerCity);
    if (ship == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(widget.seller),
              Text(
                pick(context, 'មិនស្គាល់ទីកន្លែង', 'Unknown place'),
                style: const TextStyle(color: Color(0xFF8B1E1E)),
              ),
            ],
          ),
        ),
      );
    }
    final from = MarketConfig.active.city(widget.cityId);
    final total = landedUsd(unit: widget.usd, count: _qty, shipOnce: ship.usd);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(widget.seller),
            Text(
              pick(
                context,
                'ពី ${from.nameKm} · ${moneyUsd(widget.usd)}',
                'From ${from.nameEn} · ${moneyUsd(widget.usd)}',
              ),
            ),
            Text(
              pick(
                context,
                'ដឹក ${haulCount(_qty)} ជើង · ${moneyUsd(ship.usd)} ក្នុងមួយជើង',
                '${haulCount(_qty)} ${haulCount(_qty) == 1 ? "run" : "runs"} · ${moneyUsd(ship.usd)} each',
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _open = !_open),
              child: Text(
                _open
                    ? pick(context, 'បិទចំនួន', 'Hide quantity')
                    : pick(context, 'ចំនួន', 'Quantity'),
              ),
            ),
            if (_open) QtyBar(onChanged: (n) => setState(() => _qty = n)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _pay(
                context,
                Booking(
                  kind: BookKind.goods,
                  title: '${widget.title} × $_qty',
                  amountUsd: total,
                  detail:
                      '${widget.detail} x$_qty ship:${proofTag(ship.proof)}',
                  meters: ship.meters,
                  minutes: ship.minutes,
                  proof: ship.proof,
                  card: ship.card,
                ),
              ),
              child: Text(
                '${pick(context, 'ទិញ', 'Buy')} · ${moneyUsd(total)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CharterScreen extends StatelessWidget {
  const CharterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: pick(context, 'កម្មវិធីទំនើបខ្មែរ', 'Khmer superapp'),
      children: [
        const SizedBox(
          height: 180,
          width: double.infinity,
          child: LecaArt(scene: LecaScene.seal),
        ),
        const SizedBox(height: 12),
        Text(
          charterCleared
              ? pick(context, 'បានអនុញ្ញាត', 'Cleared')
              : pick(context, 'មិនទាន់', 'Not yet'),
          key: const Key('charter_status'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB42318),
          ),
        ),
        Text(
          pick(
            context,
            'Leca គឺកម្មវិធីទំនើបខ្មែរ។ ខាងក្រោមនេះជាការអនុញ្ញាតដែលវាដំណើរការ។',
            'Leca is the Khmer superapp. These are the clearances it runs with.',
          ),
        ),
        const SizedBox(height: 12),
        for (final line in khmerClearances)
          Card(
            child: ListTile(
              leading: Icon(
                line.cleared ? Icons.verified : Icons.hourglass_top,
                color: line.cleared
                    ? const Color(0xFF1B7F3A)
                    : const Color(0xFF8A6A2F),
              ),
              title: Text(line.authorityFor(context)),
              subtitle: Text(line.scopeFor(context)),
              trailing: Text(
                line.cleared
                    ? pick(context, 'បានអនុញ្ញាត', 'Cleared')
                    : pick(context, 'មិនទាន់', 'Not yet'),
              ),
            ),
          ),
      ],
    );
  }
}

class CareScreen extends StatefulWidget {
  const CareScreen({super.key});

  @override
  State<CareScreen> createState() => _CareScreenState();
}

class _CareScreenState extends State<CareScreen> {
  final _note = TextEditingController();
  String? _siteId;
  int _count = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !lecaOnPhone(context)) return;
      unawaited(LecaScope.of(context).loadHere());
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    final origin = state.origin;
    final nearest = nearestCare(origin.latitude, origin.longitude);
    final siteId = _siteId ?? nearest.id;
    final site = careSites.firstWhere((item) => item.id == siteId);
    final quote = ambulanceQuote(
      fromLat: origin.latitude,
      fromLng: origin.longitude,
      toLat: site.latitude,
      toLng: site.longitude,
    );
    final usd = bulkUsd(quote.usd, _count);
    return _Page(
      title: pick(context, 'សង្គ្រោះបន្ទាន់', 'Emergency'),
      children: [
        const _Hero(scene: LecaScene.care, caption: ''),
        Text(
          pick(
            context,
            'រថយន្តសង្គ្រោះមករកអ្នក។ នាវិកឯករាជ្យបើក។ Leca មិនកាន់កាប់រថយន្តទេ។ ការហៅទៅនាវិកឥតគិតថ្លៃ តាម $userComms។',
            'An ambulance comes to you. An independent crew drives it. Leca does not own the vehicle. The call to the crew is free, on $userComms.',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          pick(
            context,
            'ទៅ ${site.nameKm} · ${clock(context, quote.minutes)} · ${moneyUsd(quote.usd)}',
            'To ${site.nameEn} · ${clock(context, quote.minutes)} · ${moneyUsd(quote.usd)}',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: site.id,
          items: [
            for (final item in careSites)
              DropdownMenuItem(
                value: item.id,
                child: Text(item.nameFor(context)),
              ),
          ],
          onChanged: (id) {
            if (id == null) return;
            setState(() => _siteId = id);
          },
        ),
        const SizedBox(height: 8),
        Text(
          pick(
            context,
            'ចំនួនរថយន្ត សម្រាប់ហេតុការណ៍តែមួយ រហូតដល់ $maxAmbulances។',
            'Ambulances for one incident, up to $maxAmbulances.',
          ),
        ),
        QtyBar(
          max: maxAmbulances,
          onChanged: (n) => setState(() => _count = n),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _note,
          decoration: InputDecoration(
            labelText: pick(
              context,
              'អ្វីដែលនាវិកគួរដឹង',
              'What the crew should know',
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('send_ambulance'),
          onPressed: () {
            state.setNote(_note.text);
            _pay(
              context,
              Booking(
                kind: BookKind.ride,
                title: _count == 1
                    ? '${pick(context, 'រថយន្តសង្គ្រោះ', 'Ambulance')} · ${site.nameFor(context)}'
                    : '$_count ${pick(context, 'រថយន្តសង្គ្រោះ', 'ambulances')} · ${site.nameFor(context)}',
                amountUsd: usd,
                detail: 'ambulance:${site.id} x$_count',
                vehicleId: 'ambulance',
                meters: quote.meters,
                minutes: quote.minutes,
                hours: 0,
                proof: quote.proof,
                card: quote.card,
              ),
            );
          },
          child: Text(
            '${pick(context, 'បញ្ជូនរថយន្តសង្គ្រោះ', 'Send an ambulance')} · ${moneyUsd(usd)}',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('care_call'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PhoneScreen()),
            );
          },
          child: Text(
            '${pick(context, 'ហៅនាវិក', 'Call the crew')} · ${moneyUsd(irohCallUsd)} · $userComms',
          ),
        ),
      ],
    );
  }
}
