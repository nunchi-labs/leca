import 'package:flutter/material.dart';

import 'auth.dart';
import 'l10n/app_localizations.dart';
import 'location.dart';
import 'market.dart';
import 'negotiate.dart';
import 'pay.dart';
import 'quote.dart';
import 'state.dart';
import 'traffic.dart';

class BookScreen extends StatelessWidget {
  const BookScreen({super.key, required this.kind});

  final BookKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    final market = MarketConfig.active;

    return Scaffold(
      appBar: AppBar(title: Text(_title(l10n))),
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
              Text(_body(l10n)),
              const SizedBox(height: 16),
              ..._cards(context, l10n, state, market),
            ],
          ),
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    switch (kind) {
      case BookKind.ride:
        return l10n.serviceRides;
      case BookKind.rent:
        return l10n.serviceRent;
      case BookKind.send:
        return l10n.serviceSend;
      case BookKind.goods:
        return l10n.shopTitle;
    }
  }

  String _body(AppLocalizations l10n) {
    switch (kind) {
      case BookKind.ride:
        return l10n.ridesPartnerBody;
      case BookKind.rent:
        return l10n.rentPartnerBody;
      case BookKind.send:
        return l10n.sendBody;
      case BookKind.goods:
        return l10n.saleHint;
    }
  }

  List<Widget> _cards(
    BuildContext context,
    AppLocalizations l10n,
    ChowState state,
    MarketConfig market,
  ) {
    switch (kind) {
      case BookKind.ride:
        return [
          _AutoTrip(
            l10n: l10n,
            state: state,
            offers: market.regularVehicles,
            onPay: (booking) => _pay(context, state, booking),
          ),
        ];
      case BookKind.rent:
        return [
          _TradeBoard(
            l10n: l10n,
            state: state,
            market: market,
            onPay: (booking) => _pay(context, state, booking),
          ),
        ];
      case BookKind.send:
        return [
          _AutoTrip(
            l10n: l10n,
            state: state,
            delivery: true,
            onPay: (booking) => _pay(context, state, booking),
          ),
        ];
      case BookKind.goods:
        return [Text(l10n.emptyItems)];
    }
  }

  void _pay(BuildContext context, ChowState state, Booking booking) {
    state.setBooking(booking);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PayScreen()));
  }
}

/// Where the trip ends. The fare is priced from the device to this place.
class _Dropoff extends StatelessWidget {
  const _Dropoff({
    required this.l10n,
    required this.state,
    required this.value,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final ChowState state;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButton<String>(
          key: const Key('dropoff'),
          value: value,
          items: [
            for (final city in MarketConfig.active.cities)
              DropdownMenuItem(
                value: city.id,
                child: Text(city.nameFor(state.locale)),
              ),
          ],
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
        Text(l10n.dropoff),
      ],
    );
  }
}

TripQuote _routeQuote(
  ChowState state, {
  required String dropoff,
  required int? traffic,
  required String kind,
  required String vehicle,
}) {
  final city = MarketConfig.active.city(dropoff);
  final from = state.origin;
  return priceTrip(
    kind: kind,
    vehicle: vehicle,
    fromLat: from.latitude,
    fromLng: from.longitude,
    toLat: city.latitude,
    toLng: city.longitude,
    traffic: traffic,
  );
}

Future<int?> _trafficTo(ChowState state, String dropoff) {
  final city = MarketConfig.active.city(dropoff);
  return trafficMinutes(
    from: state.origin,
    to: TripFix(latitude: city.latitude, longitude: city.longitude),
  );
}

class _AutoTrip extends StatefulWidget {
  const _AutoTrip({
    required this.l10n,
    required this.state,
    required this.onPay,
    this.offers = const [],
    this.delivery = false,
  });

  final AppLocalizations l10n;
  final ChowState state;
  final List<VehicleOffer> offers;
  final bool delivery;
  final void Function(Booking booking) onPay;

  @override
  State<_AutoTrip> createState() => _AutoTripState();
}

class _AutoTripState extends State<_AutoTrip> {
  late String _dropoff;
  int? _traffic;

  @override
  void initState() {
    super.initState();
    _dropoff = widget.state.cityId;
    _loadTraffic();
  }

  Future<void> _loadTraffic() async {
    final minutes = await _trafficTo(widget.state, _dropoff);
    if (!mounted || minutes == null) return;
    setState(() => _traffic = minutes);
  }

  TripQuote _quote(String vehicle) => _routeQuote(
    widget.state,
    dropoff: _dropoff,
    traffic: _traffic,
    kind: widget.delivery ? 'delivery' : 'ride',
    vehicle: widget.delivery ? '' : vehicle,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final state = widget.state;
    final first = _quote(widget.delivery ? '' : widget.offers.first.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Dropoff(
          l10n: l10n,
          state: state,
          value: _dropoff,
          onChanged: (id) {
            setState(() {
              _dropoff = id;
              _traffic = null;
            });
            _loadTraffic();
          },
        ),
        const SizedBox(height: 8),
        Text(l10n.autoFare(first.kilometres.toStringAsFixed(1), first.minutes)),
        const SizedBox(height: 8),
        if (widget.delivery)
          _OfferTile(
            title: l10n.sendAnythingTitle,
            subtitle: l10n.sendAnythingDetail,
            fareKey: 'send',
            lockWithDriver: true,
            quoteFor: (_) => _quote(''),
            onPay: (amount, withDriver, quote) => widget.onPay(
              Booking(
                kind: BookKind.send,
                title: 'Send anything',
                amountUsd: amount,
                detail: 'open-delivery',
                meters: quote?.meters ?? 0,
                minutes: quote?.minutes ?? 0,
                proof: quote?.proof ?? '',
              ),
            ),
            l10n: l10n,
          )
        else
          for (final offer in widget.offers)
            _OfferTile(
              title: offer.nameFor(state.locale),
              fareKey: 'ride:${offer.id}',
              lockWithDriver: true,
              quoteFor: (_) => _quote(offer.id),
              onPay: (amount, withDriver, quote) => widget.onPay(
                Booking(
                  kind: BookKind.ride,
                  title: offer.nameEn,
                  amountUsd: amount,
                  detail: withDriver ? 'with-driver' : 'self-drive',
                  vehicleId: offer.id,
                  meters: quote?.meters ?? 0,
                  minutes: quote?.minutes ?? 0,
                  proof: quote?.proof ?? '',
                ),
              ),
              l10n: l10n,
            ),
      ],
    );
  }
}

class _TradeBoard extends StatefulWidget {
  const _TradeBoard({
    required this.l10n,
    required this.state,
    required this.market,
    required this.onPay,
  });

  final AppLocalizations l10n;
  final ChowState state;
  final MarketConfig market;
  final void Function(Booking booking) onPay;

  @override
  State<_TradeBoard> createState() => _TradeBoardState();
}

class _TradeBoardState extends State<_TradeBoard> {
  bool _sale = false;
  late String _dropoff;
  int? _traffic;

  @override
  void initState() {
    super.initState();
    _dropoff = widget.state.cityId;
    _loadTraffic();
  }

  Future<void> _loadTraffic() async {
    final minutes = await _trafficTo(widget.state, _dropoff);
    if (!mounted || minutes == null) return;
    setState(() => _traffic = minutes);
  }

  /// A rental is priced place to place. With a driver it includes their time.
  TripQuote _rentQuote(String vehicle, {required bool withDriver}) =>
      _routeQuote(
        widget.state,
        dropoff: _dropoff,
        traffic: _traffic,
        kind: withDriver ? 'rent' : 'rent-self',
        vehicle: vehicle,
      );

  String _offerId(ListedVehicle vehicle) {
    final kind = vehicle.kind.toLowerCase();
    for (final offer in widget.market.exampleVehicles) {
      if (offer.id == kind || offer.nameEn.toLowerCase() == kind) {
        return offer.id;
      }
    }
    return kind;
  }

  Booking _booking({
    required String title,
    required String vehicleId,
    required double amount,
    required bool withDriver,
    required TripQuote? quote,
  }) {
    final mode = _sale ? 'sale' : 'rent';
    return Booking(
      kind: BookKind.rent,
      title: title,
      amountUsd: amount,
      detail: '$mode · ${withDriver ? 'with-driver' : 'self-drive'}',
      vehicleId: vehicleId,
      meters: quote?.meters ?? 0,
      minutes: quote?.minutes ?? 0,
      proof: quote?.proof ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final state = widget.state;
    final market = widget.market;
    final mode = _sale ? 'sale' : 'rent';
    final mine = state.vehicles
        .where((v) => state.covers(v.latitude, v.longitude))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.saleHint),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.forRent),
              selected: !_sale,
              onSelected: (_) => setState(() => _sale = false),
            ),
            ChoiceChip(
              label: Text(l10n.forSale),
              selected: _sale,
              onSelected: (_) => setState(() => _sale = true),
            ),
          ],
        ),
        if (!_sale) ...[
          const SizedBox(height: 12),
          _Dropoff(
            l10n: l10n,
            state: state,
            value: _dropoff,
            onChanged: (id) {
              setState(() {
                _dropoff = id;
                _traffic = null;
              });
              _loadTraffic();
            },
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _sale ? l10n.forSale : l10n.regularVehicles,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final v in market.regularVehicles)
          _OfferTile(
            title: v.nameFor(state.locale),
            usd: v.salePrice,
            fareKey: '$mode:${v.id}',
            initialWithDriver: v.withDriver,
            quoteFor: _sale
                ? null
                : (withDriver) => _rentQuote(v.id, withDriver: withDriver),
            onPay: (amount, withDriver, quote) => widget.onPay(
              _booking(
                title: v.nameEn,
                vehicleId: v.id,
                amount: amount,
                withDriver: withDriver,
                quote: quote,
              ),
            ),
            l10n: l10n,
          ),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.myVehicles,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final v in mine)
            _OfferTile(
              title: v.kind,
              usd: state.listedPrice(v, sale: true),
              fareKey: '$mode:listed:${v.id}',
              initialWithDriver: v.withDriver,
              quoteFor: _sale
                  ? null
                  : (withDriver) =>
                        _rentQuote(_offerId(v), withDriver: withDriver),
              onPay: (amount, withDriver, quote) => widget.onPay(
                _booking(
                  title: v.kind,
                  vehicleId: _offerId(v),
                  amount: amount,
                  withDriver: withDriver,
                  quote: quote,
                ),
              ),
              l10n: l10n,
            ),
        ],
        const SizedBox(height: 8),
        Text(l10n.rentExamplesKh),
      ],
    );
  }
}

/// One offer. With [quoteFor] the price is the automatic fare for the
/// chosen mode. With a [fareKey] either side may propose another price.
class _OfferTile extends StatefulWidget {
  const _OfferTile({
    required this.title,
    required this.onPay,
    required this.l10n,
    this.usd = 0,
    this.subtitle = '',
    this.fareKey,
    this.initialWithDriver = true,
    this.lockWithDriver = false,
    this.quoteFor,
  });

  final String title;
  final String subtitle;
  final double usd;
  final void Function(double amount, bool withDriver, TripQuote? quote) onPay;
  final AppLocalizations l10n;
  final String? fareKey;
  final bool initialWithDriver;
  final bool lockWithDriver;
  final TripQuote Function(bool withDriver)? quoteFor;

  @override
  State<_OfferTile> createState() => _OfferTileState();
}

class _OfferTileState extends State<_OfferTile> {
  late bool _withDriver;

  @override
  void initState() {
    super.initState();
    _withDriver = widget.initialWithDriver;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final state = ChowScope.of(context);
    final quote = widget.quoteFor?.call(_withDriver);
    final appUsd = quote?.usd ?? widget.usd;
    final base = widget.fareKey;
    final key = base == null
        ? null
        : quote == null
        ? base
        : '$base:${_withDriver ? 'driver' : 'self'}:${quote.meters}:${quote.minutes}';
    final agreed = key != null && state.askFor(key)?.agreedUsd != null;
    final amount = key == null ? appUsd : state.payable(key, appUsd);
    final mode = _withDriver ? l10n.withDriver : l10n.selfDrive;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                key == null
                    ? widget.subtitle
                    : '$mode · ${agreed ? l10n.agreedPrice : l10n.appPrice}',
              ),
              const SizedBox(height: 4),
              Text(
                '${moneyUsd(amount)} · ${moneyKhr(amount)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (quote != null) ...[
                Text(
                  l10n.autoFare(
                    quote.kilometres.toStringAsFixed(1),
                    quote.minutes,
                  ),
                ),
                if (quote.checksOut)
                  Text(
                    l10n.fareProof(quote.proof.substring(0, 12)),
                    key: Key('fare_proof_${base ?? widget.title}'),
                  ),
              ],
              if (key != null) ...[
                const SizedBox(height: 8),
                if (!widget.lockWithDriver)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _withDriver,
                    title: Text(mode),
                    onChanged: (value) => setState(() => _withDriver = value),
                  )
                else
                  Text(mode),
                FareNegotiate(fareKey: key, appUsd: appUsd),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => widget.onPay(amount, _withDriver, quote),
                  child: Text(l10n.checkout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
