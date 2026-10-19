import 'dart:math' as math;

import 'geo.dart';
import 'rate_card.dart';
import 'traffic.dart';

/// How the two of you are apart.
enum GapWay { crow, walk, drive }

/// One way of measuring the same two points.
class GapLeg {
  const GapLeg({
    required this.way,
    required this.meters,
    required this.minutes,
    this.routed = false,
  });

  final GapWay way;
  final int meters;

  /// Zero for a straight-line gap. Walking and driving have a time.
  final int minutes;

  /// True when a live route replaced the estimate.
  final bool routed;

  double get kilometres => meters / 1000;
}

/// Crow, walk, and drive for one pair of points.
class Gap {
  const Gap({required this.crow, required this.walk, required this.drive});

  final GapLeg crow;
  final GapLeg walk;
  final GapLeg drive;

  GapLeg leg(GapWay way) {
    switch (way) {
      case GapWay.crow:
        return crow;
      case GapWay.walk:
        return walk;
      case GapWay.drive:
        return drive;
    }
  }
}

/// Footpaths wander a little past the straight line.
const walkPathFactor = 1.15;

/// A person on foot, kilometres per hour.
const walkKmh = 5.0;

/// Under this, the two of you are in the same place.
const togetherMeters = 30;

int _walkMinutes(int meters) {
  if (meters <= 0) return 0;
  final hours = meters / (walkKmh * 1000);
  return (hours * 60).ceil();
}

/// Straight line, a walk, and a drive. The walk and the drive are estimates
/// until a live route replaces them.
Gap gapBetween(
  double lat1,
  double lng1,
  double lat2,
  double lng2, {
  RateCard? card,
}) {
  final rates = card ?? RateCard.active;
  final crowMeters = (kmBetween(lat1, lng1, lat2, lng2) * 1000).round();
  if (crowMeters < togetherMeters) {
    return Gap(
      crow: const GapLeg(way: GapWay.crow, meters: 0, minutes: 0),
      walk: const GapLeg(way: GapWay.walk, meters: 0, minutes: 0),
      drive: const GapLeg(way: GapWay.drive, meters: 0, minutes: 0),
    );
  }
  final walkMeters = (crowMeters * walkPathFactor).round();
  final driveMeters = rates.roadMeters(crowMeters / 1000);
  return Gap(
    crow: GapLeg(way: GapWay.crow, meters: crowMeters, minutes: 0),
    walk: GapLeg(
      way: GapWay.walk,
      meters: walkMeters,
      minutes: _walkMinutes(walkMeters),
    ),
    drive: GapLeg(
      way: GapWay.drive,
      meters: driveMeters,
      minutes: rates.tripMinutes(driveMeters, null),
    ),
  );
}

/// Keeps the straight line. A live walk or drive replaces that estimate.
Gap gapWithRoutes(Gap estimate, {RoadRoute? walk, RoadRoute? drive}) {
  GapLeg live(GapLeg leg, RoadRoute? route) {
    if (route == null || route.meters < 1) return leg;
    return GapLeg(
      way: leg.way,
      meters: route.meters,
      minutes: route.minutes < 1 ? 1 : route.minutes,
      routed: true,
    );
  }

  return Gap(
    crow: estimate.crow,
    walk: live(estimate.walk, walk),
    drive: live(estimate.drive, drive),
  );
}

/// The rectangle a chart uses, in degrees, with room around both pins.
class MapFrame {
  const MapFrame({
    required this.west,
    required this.east,
    required this.south,
    required this.north,
  });

  final double west;
  final double east;
  final double south;
  final double north;

  double get widthDegrees => (east - west).abs();

  double get heightDegrees => (north - south).abs();

  /// Kilometres across the bottom edge. That is the scale of the chart.
  double get widthKm => kmBetween(south, west, south, east);
}

MapFrame mapFrame(double lat1, double lng1, double lat2, double lng2) {
  var south = math.min(lat1, lat2);
  var north = math.max(lat1, lat2);
  var west = math.min(lng1, lng2);
  var east = math.max(lng1, lng2);
  final latPad = math.max((north - south) * 0.45, 0.08);
  final lngPad = math.max((east - west) * 0.45, 0.08);
  south -= latPad;
  north += latPad;
  west -= lngPad;
  east += lngPad;
  return MapFrame(west: west, east: east, south: south, north: north);
}

/// Metres, as a short distance. Under a kilometre stays in metres.
String gapDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
