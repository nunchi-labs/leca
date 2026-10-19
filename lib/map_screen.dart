import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'apart.dart';
import 'l10n/app_localizations.dart';
import 'location.dart';
import 'market.dart';
import 'reach.dart';
import 'state.dart';
import 'traffic.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String? _me;
  String _them = 'siem_reap';
  var _set = false;
  Gap? _gap;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh(LecaScope.of(context)));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_set) return;
    _set = true;
    final city = LecaScope.of(context).cityId;
    _me = city;
    _them = city == 'siem_reap' ? 'phnom_penh' : 'siem_reap';
  }

  TripFix _fix(LecaState state, String cityId) {
    if (cityId == state.cityId) return state.origin;
    final city = MarketConfig.active.city(cityId);
    return TripFix(latitude: city.latitude, longitude: city.longitude);
  }

  Future<void> _refresh(LecaState state) async {
    final me = _fix(state, _me ?? state.cityId);
    final them = _fix(state, _them);
    final estimate = gapBetween(
      me.latitude,
      me.longitude,
      them.latitude,
      them.longitude,
    );
    if (!mounted) return;
    setState(() => _gap = estimate);
    final token = state.session?.token;
    final walked = await roadRoute(
      from: me,
      to: them,
      token: token,
      mode: 'WALK',
    );
    final driven = await roadRoute(from: me, to: them, token: token);
    if (!mounted) return;
    setState(() => _gap = gapWithRoutes(estimate, walk: walked, drive: driven));
  }

  @override
  Widget build(BuildContext context) {
    final state = LecaScope.of(context);
    final l10n = AppLocalizations.of(context);
    final meId = _me ?? state.cityId;
    final me = _fix(state, meId);
    final them = _fix(state, _them);
    final gap =
        _gap ??
        gapBetween(me.latitude, me.longitude, them.latitude, them.longitude);
    final meCity = MarketConfig.active.city(meId);
    final themCity = MarketConfig.active.city(_them);
    final meName = state.session?.displayName ?? '';
    final mine = meName.isEmpty ? pick(context, 'អ្នក', 'You') : meName;
    final theirs = themCity.nameFor(state.locale);
    final card = _share(
      context,
      mine: mine,
      mePlace: meCity.nameFor(state.locale),
      theirs: theirs,
      gap: gap,
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serviceMap)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                pick(
                  context,
                  'មនុស្សពីរនាក់ លើផែនទីតែមួយ។ ចម្ងាយត្រង់ ដើរ និងបើក។',
                  'Two people, one map. Straight across, on foot, and by road.',
                ),
              ),
              const SizedBox(height: 12),
              _CityMenu(
                label: pick(context, 'ខ្ញុំនៅ', 'I am in'),
                value: meId,
                locale: state.locale,
                onChanged: (id) {
                  setState(() {
                    _me = id;
                    _gap = null;
                  });
                  unawaited(_refresh(state));
                },
              ),
              _CityMenu(
                label: pick(context, 'គេនៅ', 'They are in'),
                value: _them,
                locale: state.locale,
                onChanged: (id) {
                  setState(() {
                    _them = id;
                    _gap = null;
                  });
                  unawaited(_refresh(state));
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CustomPaint(
                    painter: _GapPainter(
                      me: me,
                      them: them,
                      meLabel: mine,
                      themLabel: theirs,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Stat(
                key: const Key('map_crow'),
                title: pick(context, 'ចម្ងាយត្រង់', 'As the crow flies'),
                body: gapDistance(gap.crow.meters),
              ),
              _Stat(
                key: const Key('map_walk'),
                title: pick(context, 'ដើរ', 'Walking'),
                body:
                    '${gapDistance(gap.walk.meters)} · ${clock(context, gap.walk.minutes)}',
              ),
              _Stat(
                key: const Key('map_drive'),
                title: pick(context, 'បើក', 'Driving'),
                body:
                    '${gapDistance(gap.drive.meters)} · ${clock(context, gap.drive.minutes)}',
              ),
              const SizedBox(height: 8),
              Text(
                gap.drive.routed
                    ? pick(
                        context,
                        'ការដើរ និងការបើកមកពីផ្លូវផ្ទាល់។',
                        'The walk and the drive are a live route.',
                      )
                    : pick(
                        context,
                        'ការដើរ និងការបើកជាការប៉ាន់។ ចម្ងាយត្រង់គឺចម្ងាយពិត។',
                        'The walk and the drive are estimates. The straight line is exact.',
                      ),
                style: const TextStyle(color: Color(0xFF5C534C)),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('map_share'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: card));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(l10n.phoneCopied)));
                },
                child: Text(pick(context, 'ចម្លងឱ្យគេ', 'Copy for them')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _share(
    BuildContext context, {
    required String mine,
    required String mePlace,
    required String theirs,
    required Gap gap,
  }) {
    return [
      'Leca map',
      '$mine · $mePlace → $theirs',
      '${pick(context, 'ចម្ងាយត្រង់', 'As the crow flies')}: ${gapDistance(gap.crow.meters)}',
      '${pick(context, 'ដើរ', 'Walking')}: ${gapDistance(gap.walk.meters)} · ${clock(context, gap.walk.minutes)}',
      '${pick(context, 'បើក', 'Driving')}: ${gapDistance(gap.drive.meters)} · ${clock(context, gap.drive.minutes)}',
    ].join('\n');
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
        SizedBox(width: 92, child: Text(label)),
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

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(
          body,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GapPainter extends CustomPainter {
  const _GapPainter({
    required this.me,
    required this.them,
    required this.meLabel,
    required this.themLabel,
  });

  final TripFix me;
  final TripFix them;
  final String meLabel;
  final String themLabel;

  static const _water = Color(0xFFD5E4EE);
  static const _land = Color(0xFFF3E6D4);
  static const _ink = Color(0xFF1A1410);
  static const _pepper = Color(0xFFB42318);
  static const _leaf = Color(0xFF2F6B4F);
  static const _gold = Color(0xFF8A6A2F);
  static const _pool = Color(0xFFB7D0DE);

  /// Tonle Sap, rough, so a long chart still has a landmark.
  static const _tonle = <(double, double)>[
    (12.55, 103.75),
    (12.95, 103.55),
    (13.25, 103.85),
    (13.15, 104.25),
    (12.75, 104.55),
    (12.45, 104.15),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final frame = mapFrame(
      me.latitude,
      me.longitude,
      them.latitude,
      them.longitude,
    );
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = _water)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
          const Radius.circular(12),
        ),
        Paint()..color = _land,
      );
    final lake = Path();
    for (var i = 0; i < _tonle.length; i++) {
      final spot = _at(frame, size, _tonle[i].$1, _tonle[i].$2);
      if (i == 0) {
        lake.moveTo(spot.dx, spot.dy);
      } else {
        lake.lineTo(spot.dx, spot.dy);
      }
    }
    lake.close();
    canvas.drawPath(lake, Paint()..color = _pool);
    _grid(canvas, size);
    final a = _at(frame, size, me.latitude, me.longitude);
    final b = _at(frame, size, them.latitude, them.longitude);
    _leg(canvas, a, b, _gold, bowed: 0);
    _leg(canvas, a, b, _leaf, bowed: 18);
    _leg(canvas, a, b, _pepper, bowed: -18);
    _pin(canvas, a, _pepper, meLabel, above: true);
    _pin(canvas, b, _ink, themLabel, above: false);
    _scale(canvas, size, frame);
  }

  void _grid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas
        ..drawLine(Offset(x, 8), Offset(x, size.height - 8), paint)
        ..drawLine(Offset(8, y), Offset(size.width - 8, y), paint);
    }
  }

  void _leg(
    Canvas canvas,
    Offset a,
    Offset b,
    Color color, {
    required double bowed,
  }) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final bend = len < 1 ? Offset.zero : Offset(-dy / len, dx / len) * bowed;
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, b.dx, b.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = bowed == 0 ? 2.5 : 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _pin(
    Canvas canvas,
    Offset at,
    Color color,
    String label, {
    required bool above,
  }) {
    canvas
      ..drawCircle(at, 7, Paint()..color = Colors.white)
      ..drawCircle(at, 5, Paint()..color = color);
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);
    final dy = above ? -painter.height - 10 : 10.0;
    painter.paint(canvas, Offset(at.dx - painter.width / 2, at.dy + dy));
  }

  void _scale(Canvas canvas, Size size, MapFrame frame) {
    final km = frame.widthKm / 4;
    final label = gapDistance((km * 1000).round());
    final bar = size.width / 4;
    final origin = Offset(20, size.height - 22);
    canvas.drawLine(
      origin,
      origin + Offset(bar, 0),
      Paint()
        ..color = _ink
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: _ink, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, origin + const Offset(0, -16));
  }

  Offset _at(MapFrame frame, Size size, double lat, double lng) {
    final x = (lng - frame.west) / frame.widthDegrees * size.width;
    final y = (frame.north - lat) / frame.heightDegrees * size.height;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _GapPainter oldDelegate) =>
      oldDelegate.me.latitude != me.latitude ||
      oldDelegate.me.longitude != me.longitude ||
      oldDelegate.them.latitude != them.latitude ||
      oldDelegate.them.longitude != them.longitude ||
      oldDelegate.meLabel != meLabel ||
      oldDelegate.themLabel != themLabel;
}
