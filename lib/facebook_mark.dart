import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular Facebook mark in Facebook Blue.
///
/// Meta's minimum digital size is 16px, and that is the logo on
/// Facebook's own login button.
class FacebookMark extends StatelessWidget {
  const FacebookMark({super.key});

  static const double size = 16;

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FacebookMarkPainter()),
      ),
    );
  }
}

class _FacebookMarkPainter extends CustomPainter {
  const _FacebookMarkPainter();

  static final Path _path = _facebookPath();

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..scale(size.width / 24)
      ..drawPath(_path, Paint()..color = const Color(0xFF0866FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Current circular logo. The white “f” is the hole in the blue disc.
@visibleForTesting
Path facebookLogoPath() => _facebookPath();

Path _facebookPath() {
  return _svgPath(
    [
      'M9.101 23.691v-7.98H6.627v-3.667h2.474v-1.58c0-4.085 1.848-5.978 ',
      '5.858-5.978.401 0 .955.042 1.468.103a8.68 8.68 0 0 1 1.141.195v3.325',
      'a8.623 8.623 0 0 0-.653-.036 26.805 26.805 0 0 0-.733-.009c-.707 0',
      '-1.259.096-1.675.309a1.686 1.686 0 0 0-.679.622c-.258.42-.374.995',
      '-.374 1.752v1.297h3.919l-.386 2.103-.287 1.564h-3.246v8.245',
      'C19.396 23.238 24 18.179 24 12.044c0-6.627-5.373-12-12-12s-12 5.373',
      '-12 12c0 5.628 3.874 10.35 9.101 11.647Z',
    ].join(),
  );
}

Path _svgPath(String data) {
  final tokens = RegExp(
    r'[MmLlHhVvCcSsAaZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((match) => match.group(0)!).toList();
  final path = Path();
  var index = 0;
  var steps = 0;
  String? command;
  var x = 0.0;
  var y = 0.0;
  var startX = 0.0;
  var startY = 0.0;
  var controlX = 0.0;
  var controlY = 0.0;
  var cubic = false;

  double number() => double.parse(tokens[index++]);

  while (index < tokens.length) {
    if (++steps > 200) {
      throw StateError('logo path did not finish at $index');
    }
    if (RegExp(r'^[A-Za-z]$').hasMatch(tokens[index])) {
      command = tokens[index++];
    }
    if (command == null) break;
    final relative = command == command.toLowerCase();
    switch (command.toUpperCase()) {
      case 'M':
        final nx = number();
        final ny = number();
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.moveTo(x, y);
        startX = x;
        startY = y;
        command = relative ? 'l' : 'L';
        cubic = false;
      case 'L':
        final nx = number();
        final ny = number();
        x = relative ? x + nx : nx;
        y = relative ? y + ny : ny;
        path.lineTo(x, y);
        cubic = false;
      case 'H':
        final nx = number();
        x = relative ? x + nx : nx;
        path.lineTo(x, y);
        cubic = false;
      case 'V':
        final ny = number();
        y = relative ? y + ny : ny;
        path.lineTo(x, y);
        cubic = false;
      case 'C':
        var x1 = number();
        var y1 = number();
        var x2 = number();
        var y2 = number();
        var nx = number();
        var ny = number();
        if (relative) {
          x1 += x;
          y1 += y;
          x2 += x;
          y2 += y;
          nx += x;
          ny += y;
        }
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        controlX = x2;
        controlY = y2;
        x = nx;
        y = ny;
        cubic = true;
      case 'S':
        var x2 = number();
        var y2 = number();
        var nx = number();
        var ny = number();
        if (relative) {
          x2 += x;
          y2 += y;
          nx += x;
          ny += y;
        }
        final x1 = cubic ? 2 * x - controlX : x;
        final y1 = cubic ? 2 * y - controlY : y;
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        controlX = x2;
        controlY = y2;
        x = nx;
        y = ny;
        cubic = true;
      case 'A':
        final rx = number().abs();
        final ry = number().abs();
        final rotation = number() * math.pi / 180;
        final large = number() != 0;
        final sweep = number() != 0;
        var nx = number();
        var ny = number();
        if (relative) {
          nx += x;
          ny += y;
        }
        _ellipticalArc(path, x, y, rx, ry, rotation, large, sweep, nx, ny);
        x = nx;
        y = ny;
        cubic = false;
      case 'Z':
        path.close();
        x = startX;
        y = startY;
        cubic = false;
    }
  }
  return path;
}

/// SVG elliptical arc as cubics. [Path.arcToPoint] stalls on the flat
/// curves in this logo.
void _ellipticalArc(
  Path path,
  double x1,
  double y1,
  double rx,
  double ry,
  double rotation,
  bool large,
  bool sweep,
  double x2,
  double y2,
) {
  var radiusX = rx;
  var radiusY = ry;
  if (radiusX == 0 || radiusY == 0 || (x1 == x2 && y1 == y2)) {
    path.lineTo(x2, y2);
    return;
  }
  final cosPhi = math.cos(rotation);
  final sinPhi = math.sin(rotation);
  final dx = (x1 - x2) / 2;
  final dy = (y1 - y2) / 2;
  final x1p = cosPhi * dx + sinPhi * dy;
  final y1p = -sinPhi * dx + cosPhi * dy;
  var radiusXSq = radiusX * radiusX;
  var radiusYSq = radiusY * radiusY;
  final lambda = x1p * x1p / radiusXSq + y1p * y1p / radiusYSq;
  if (lambda > 1) {
    final scale = math.sqrt(lambda);
    radiusX *= scale;
    radiusY *= scale;
    radiusXSq = radiusX * radiusX;
    radiusYSq = radiusY * radiusY;
  }
  final radical =
      radiusXSq * radiusYSq - radiusXSq * y1p * y1p - radiusYSq * x1p * x1p;
  final den = radiusXSq * y1p * y1p + radiusYSq * x1p * x1p;
  var coef = radical <= 0 || den == 0 ? 0.0 : math.sqrt(radical / den);
  if (large == sweep) coef = -coef;
  final cxp = coef * radiusX * y1p / radiusY;
  final cyp = -coef * radiusY * x1p / radiusX;
  final cx = cosPhi * cxp - sinPhi * cyp + (x1 + x2) / 2;
  final cy = sinPhi * cxp + cosPhi * cyp + (y1 + y2) / 2;

  double vectorAngle(double ux, double uy, double vx, double vy) {
    final dot = ux * vx + uy * vy;
    final lengths = math.sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy));
    final angle = math.acos((dot / lengths).clamp(-1.0, 1.0));
    return ux * vy - uy * vx < 0 ? -angle : angle;
  }

  final theta1 = vectorAngle(
    1,
    0,
    (x1p - cxp) / radiusX,
    (y1p - cyp) / radiusY,
  );
  var delta = vectorAngle(
    (x1p - cxp) / radiusX,
    (y1p - cyp) / radiusY,
    (-x1p - cxp) / radiusX,
    (-y1p - cyp) / radiusY,
  );
  if (!sweep && delta > 0) delta -= 2 * math.pi;
  if (sweep && delta < 0) delta += 2 * math.pi;
  final segments = math.max(1, (delta.abs() / (math.pi / 2)).ceil());
  final step = delta / segments;
  final t = 4 / 3 * math.tan(step / 4);
  var angle = theta1;
  for (var i = 0; i < segments; i++) {
    final next = angle + step;
    Offset point(double a) {
      final c = math.cos(a);
      final s = math.sin(a);
      return Offset(
        cx + radiusX * (cosPhi * c - sinPhi * s),
        cy + radiusY * (sinPhi * c + cosPhi * s),
      );
    }

    Offset tangent(double a) {
      final c = math.cos(a);
      final s = math.sin(a);
      return Offset(
        -radiusX * cosPhi * s - radiusY * sinPhi * c,
        -radiusX * sinPhi * s + radiusY * cosPhi * c,
      );
    }

    final p1 = point(angle);
    final p2 = i == segments - 1 ? Offset(x2, y2) : point(next);
    final d1 = tangent(angle);
    final d2 = tangent(next);
    path.cubicTo(
      p1.dx + t * d1.dx,
      p1.dy + t * d1.dy,
      p2.dx - t * d2.dx,
      p2.dy - t * d2.dy,
      p2.dx,
      p2.dy,
    );
    angle = next;
  }
}
