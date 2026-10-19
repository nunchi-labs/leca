import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Anime scenes drawn in the app. Original, not a copied character.
enum LecaScene {
  hero,
  bus,
  air,
  fiber,
  call,
  market,
  seal,
  care,
  bowl,
  shop,
  map,
}

class LecaArt extends StatelessWidget {
  const LecaArt({required this.scene, super.key, this.radius = 16});

  final LecaScene scene;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CustomPaint(
        painter: _AnimePainter(scene),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AnimePainter extends CustomPainter {
  const _AnimePainter(this.scene);

  final LecaScene scene;

  static const _ink = Color(0xFF1A1410);
  static const _skin = Color(0xFFF6C7A8);
  static const _blush = Color(0xFFE8837A);
  static const _pepper = Color(0xFFB42318);
  static const _gold = Color(0xFFC6A15B);
  static const _rice = Color(0xFFF6F0E6);
  static const _sky = Color(0xFFD7E6F2);
  static const _leaf = Color(0xFF2F6B4F);
  static const _white = Color(0xFFFFF8F2);

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 160;
    _backdrop(canvas, size);
    switch (scene) {
      case LecaScene.hero:
        _bust(
          canvas,
          Offset(size.width * 0.5, size.height * 0.58),
          unit * 1.35,
          shirt: _pepper,
        );
      case LecaScene.bus:
        _coach(canvas, size);
        _bust(
          canvas,
          Offset(size.width * 0.28, size.height * 0.62),
          unit,
          shirt: _pepper,
        );
      case LecaScene.air:
        _plane(canvas, size);
        _bust(
          canvas,
          Offset(size.width * 0.72, size.height * 0.68),
          unit * 0.9,
          shirt: _gold,
        );
      case LecaScene.fiber:
        _cable(canvas, size);
        _bust(
          canvas,
          Offset(size.width * 0.3, size.height * 0.64),
          unit,
          shirt: _leaf,
        );
      case LecaScene.call:
        _bust(
          canvas,
          Offset(size.width * 0.28, size.height * 0.62),
          unit * 0.95,
          shirt: _pepper,
        );
        _bust(
          canvas,
          Offset(size.width * 0.72, size.height * 0.62),
          unit * 0.95,
          shirt: _gold,
          flip: true,
        );
        _arc(canvas, size);
      case LecaScene.market:
        _parcel(canvas, Offset(size.width * 0.5, size.height * 0.62), unit);
        _bust(
          canvas,
          Offset(size.width * 0.28, size.height * 0.64),
          unit * 0.9,
          shirt: _pepper,
        );
        _bust(
          canvas,
          Offset(size.width * 0.74, size.height * 0.64),
          unit * 0.9,
          shirt: _leaf,
          flip: true,
        );
      case LecaScene.seal:
        _seal(canvas, size);
      case LecaScene.care:
        _van(canvas, size);
        _bust(
          canvas,
          Offset(size.width * 0.34, size.height * 0.6),
          unit,
          shirt: _leaf,
        );
      case LecaScene.bowl:
        _bowl(canvas, size);
      case LecaScene.shop:
        _stall(canvas, size);
        _bust(
          canvas,
          Offset(size.width * 0.62, size.height * 0.62),
          unit,
          shirt: _pepper,
        );
      case LecaScene.map:
        _chart(canvas, size);
    }
  }

  void _backdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sky = scene == LecaScene.seal || scene == LecaScene.care
        ? _pepper
        : _sky;
    canvas.drawRect(rect, Paint()..color = sky);
    if (scene == LecaScene.seal || scene == LecaScene.care) return;
    canvas
      ..drawRect(
        Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
        Paint()..color = _rice,
      )
      ..drawCircle(
        Offset(size.width * 0.82, size.height * 0.22),
        size.shortestSide * 0.12,
        Paint()..color = const Color(0xFFFFE3A3),
      );
  }

  void _bust(
    Canvas canvas,
    Offset center,
    double s, {
    required Color shirt,
    bool flip = false,
  }) {
    canvas
      ..save()
      ..translate(center.dx, center.dy);
    if (flip) canvas.scale(-1, 1);
    final hair = Paint()..color = _ink;
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(0, -18 * s),
          width: 78 * s,
          height: 90 * s,
        ),
        hair,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, 28 * s),
            width: 70 * s,
            height: 46 * s,
          ),
          Radius.circular(16 * s),
        ),
        Paint()..color = shirt,
      )
      ..drawCircle(Offset(0, 8 * s), 10 * s, Paint()..color = _skin)
      ..drawOval(
        Rect.fromCenter(
          center: Offset(0, -16 * s),
          width: 58 * s,
          height: 64 * s,
        ),
        Paint()..color = _skin,
      );
    final bangs = Path()
      ..moveTo(-30 * s, -22 * s)
      ..quadraticBezierTo(-10 * s, -8 * s, 0, -18 * s)
      ..quadraticBezierTo(12 * s, -6 * s, 30 * s, -24 * s)
      ..lineTo(32 * s, -46 * s)
      ..quadraticBezierTo(0, -58 * s, -32 * s, -44 * s)
      ..close();
    canvas.drawPath(bangs, hair);
    _eye(canvas, Offset(-12 * s, -16 * s), s);
    _eye(canvas, Offset(12 * s, -16 * s), s);
    canvas
      ..drawCircle(Offset(-18 * s, -4 * s), 5 * s, Paint()..color = _blush)
      ..drawCircle(Offset(18 * s, -4 * s), 5 * s, Paint()..color = _blush)
      ..drawArc(
        Rect.fromCenter(
          center: Offset(0, -2 * s),
          width: 12 * s,
          height: 8 * s,
        ),
        0.2,
        2.6,
        false,
        Paint()
          ..color = _pepper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  void _eye(Canvas canvas, Offset at, double s) {
    canvas
      ..drawOval(
        Rect.fromCenter(center: at, width: 16 * s, height: 18 * s),
        Paint()..color = _white,
      )
      ..drawCircle(
        at.translate(1 * s, 1 * s),
        5.5 * s,
        Paint()..color = const Color(0xFF5C3317),
      )
      ..drawCircle(at.translate(1 * s, 1 * s), 2.6 * s, Paint()..color = _ink)
      ..drawCircle(at.translate(-2 * s, -3 * s), 2 * s, Paint()..color = _white)
      ..drawOval(
        Rect.fromCenter(
          center: at.translate(0, -9 * s),
          width: 14 * s,
          height: 4 * s,
        ),
        Paint()..color = _ink,
      );
  }

  void _coach(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.38,
        size.height * 0.42,
        size.width * 0.52,
        size.height * 0.28,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(body, Paint()..color = _pepper);
    final window = Paint()..color = _sky;
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.width * (0.44 + i * 0.14),
            size.height * 0.48,
            size.width * 0.1,
            size.height * 0.1,
          ),
          const Radius.circular(4),
        ),
        window,
      );
    }
    final wheel = Paint()..color = _ink;
    canvas
      ..drawCircle(Offset(size.width * 0.5, size.height * 0.72), 8, wheel)
      ..drawCircle(Offset(size.width * 0.78, size.height * 0.72), 8, wheel);
  }

  void _plane(Canvas canvas, Size size) {
    final paint = Paint()..color = _white;
    final nose = Offset(size.width * 0.62, size.height * 0.36);
    final path = Path()
      ..moveTo(nose.dx, nose.dy)
      ..lineTo(nose.dx - size.width * 0.28, nose.dy + 8)
      ..lineTo(nose.dx - size.width * 0.22, nose.dy + 2)
      ..lineTo(nose.dx - size.width * 0.08, nose.dy + 2)
      ..close();
    canvas
      ..drawPath(path, paint)
      ..drawOval(
        Rect.fromCenter(center: nose.translate(-18, 6), width: 46, height: 16),
        paint,
      );
  }

  void _cable(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.4,
        size.width * 0.7,
        size.height * 0.62,
      );
    canvas
      ..drawPath(path, paint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * 0.72, size.height * 0.38),
            width: 36,
            height: 28,
          ),
          const Radius.circular(6),
        ),
        Paint()..color = _ink,
      );
    final wave = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 1; i <= 3; i++) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.84, size.height * 0.34),
          width: (10 + i * 8).toDouble(),
          height: (10 + i * 8).toDouble(),
        ),
        -math.pi / 3,
        math.pi / 1.6,
        false,
        wave,
      );
    }
  }

  void _arc(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pepper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.18,
        size.width * 0.4,
        size.height * 0.36,
      ),
      math.pi,
      math.pi,
      false,
      paint,
    );
  }

  void _parcel(Canvas canvas, Offset at, double s) {
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 36 * s, height: 28 * s),
          Radius.circular(4 * s),
        ),
        Paint()..color = _gold,
      )
      ..drawLine(
        at.translate(0, -14 * s),
        at.translate(0, 14 * s),
        Paint()
          ..color = _pepper
          ..strokeWidth = 3,
      );
  }

  void _seal(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.38;
    canvas
      ..drawCircle(c, r, Paint()..color = _gold)
      ..drawCircle(
        c,
        r * 0.86,
        Paint()
          ..color = _pepper
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(math.cos(a), math.sin(a)) * (r * 0.62),
          width: r * 0.28,
          height: r * 0.16,
        ),
        Paint()..color = _gold,
      );
    }
    _bust(
      canvas,
      c.translate(0, r * 0.08),
      size.shortestSide / 220,
      shirt: _pepper,
    );
  }

  void _van(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.48,
          size.height * 0.4,
          size.width * 0.4,
          size.height * 0.28,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = _white,
    );
    _heart(canvas, Offset(size.width * 0.68, size.height * 0.52), 10);
    canvas
      ..drawCircle(
        Offset(size.width * 0.58, size.height * 0.7),
        7,
        Paint()..color = _ink,
      )
      ..drawCircle(
        Offset(size.width * 0.8, size.height * 0.7),
        7,
        Paint()..color = _ink,
      );
  }

  void _heart(Canvas canvas, Offset at, double s) {
    final path = Path()
      ..moveTo(at.dx, at.dy + s)
      ..cubicTo(
        at.dx - s * 1.4,
        at.dy - s * 0.2,
        at.dx - s * 0.8,
        at.dy - s * 1.3,
        at.dx,
        at.dy - s * 0.4,
      )
      ..cubicTo(
        at.dx + s * 0.8,
        at.dy - s * 1.3,
        at.dx + s * 1.4,
        at.dy - s * 0.2,
        at.dx,
        at.dy + s,
      );
    canvas.drawPath(path, Paint()..color = _leaf);
  }

  void _bowl(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.58);
    canvas
      ..drawOval(
        Rect.fromCenter(center: c.translate(0, 16), width: 90, height: 36),
        Paint()..color = _white,
      )
      ..drawOval(
        Rect.fromCenter(center: c, width: 78, height: 28),
        Paint()..color = const Color(0xFFE7B15A),
      );
    final noodle = Paint()
      ..color = _pepper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, -6), width: 40, height: 20),
      math.pi,
      math.pi,
      false,
      noodle,
    );
    _bust(
      canvas,
      Offset(size.width * 0.78, size.height * 0.42),
      size.shortestSide / 280,
      shirt: _pepper,
    );
  }

  void _stall(Canvas canvas, Size size) {
    canvas
      ..drawRect(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.34,
          size.width * 0.36,
          8,
        ),
        Paint()..color = _pepper,
      )
      ..drawRect(
        Rect.fromLTWH(
          size.width * 0.14,
          size.height * 0.42,
          size.width * 0.32,
          size.height * 0.22,
        ),
        Paint()..color = _gold,
      );
  }

  void _chart(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _ink
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas
      ..drawLine(
        Offset(size.width * 0.18, size.height * 0.72),
        Offset(size.width * 0.78, size.height * 0.38),
        paint,
      )
      ..drawCircle(
        Offset(size.width * 0.18, size.height * 0.72),
        6,
        Paint()..color = _pepper,
      )
      ..drawCircle(
        Offset(size.width * 0.78, size.height * 0.38),
        6,
        Paint()..color = _ink,
      );
  }

  @override
  bool shouldRepaint(covariant _AnimePainter oldDelegate) =>
      oldDelegate.scene != scene;
}
