import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'location.dart';
import 'rate_card.dart';

/// Minutes from Google Routes with live traffic. Empty when the server has no key.
class TrafficMinutes extends StatefulWidget {
  const TrafficMinutes({
    super.key,
    required this.from,
    required this.to,
    required this.label,
    this.token,
  });

  final TripFix from;
  final TripFix to;
  final String Function(int minutes) label;
  final String? token;

  @override
  State<TrafficMinutes> createState() => _TrafficMinutesState();
}

class _TrafficMinutesState extends State<TrafficMinutes> {
  int? _minutes;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final minutes = await trafficMinutes(
      from: widget.from,
      to: widget.to,
      token: widget.token,
    );
    if (!mounted || minutes == null) return;
    setState(() => _minutes = minutes);
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _minutes;
    if (minutes == null) return const SizedBox.shrink();
    return Text(widget.label(minutes));
  }
}

/// A routed road: minutes in today's traffic and metres along the road.
/// Kampot to Kep is not a straight line, and neither is anything that
/// crosses the Tonle Sap.
class RoadRoute {
  const RoadRoute({required this.minutes, required this.meters});

  final int minutes;
  final int meters;
}

Future<RoadRoute?> roadRoute({
  required TripFix from,
  required TripFix to,
  String? token,
  String mode = 'DRIVE',
}) async {
  if (!AuthConfig.apiLive) return null;
  final travel = mode == 'WALK' ? 'WALK' : 'DRIVE';
  try {
    final response = await http
        .post(
          Uri.parse('${AuthConfig.apiBase}/v1/route'),
          headers: {
            'content-type': 'application/json',
            if (token != null && token.isNotEmpty)
              'authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'originLat': from.latitude,
            'originLng': from.longitude,
            'destLat': to.latitude,
            'destLng': to.longitude,
            'mode': travel,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final minutes = decoded['minutes'];
    if (minutes is! int || minutes < 1) return null;
    final meters = decoded['distanceMeters'];
    return RoadRoute(
      minutes: minutes,
      meters: meters is int && meters > 0 ? meters : 0,
    );
  } on Object catch (_) {
    return null;
  }
}

Future<int?> trafficMinutes({
  required TripFix from,
  required TripFix to,
  String? token,
}) async => (await roadRoute(from: from, to: to, token: token))?.minutes;

/// The rate card the server is pricing on today, or null offline.
Future<RateCard?> fetchRateCard() async {
  if (!AuthConfig.apiLive) return null;
  try {
    final response = await http
        .get(Uri.parse('${AuthConfig.apiBase}/v1/card'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    return RateCard.fromJson(jsonDecode(response.body));
  } on Object catch (_) {
    return null;
  }
}
