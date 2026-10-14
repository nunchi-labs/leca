import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'location.dart';

/// Minutes from Google Routes with live traffic. Empty when the server has no key.
class TrafficMinutes extends StatefulWidget {
  const TrafficMinutes({
    super.key,
    required this.from,
    required this.to,
    required this.label,
  });

  final TripFix from;
  final TripFix to;
  final String Function(int minutes) label;

  @override
  State<TrafficMinutes> createState() => _TrafficMinutesState();
}

class _TrafficMinutesState extends State<TrafficMinutes> {
  int? _minutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final minutes = await trafficMinutes(from: widget.from, to: widget.to);
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

Future<int?> trafficMinutes({
  required TripFix from,
  required TripFix to,
}) async {
  if (!AuthConfig.apiLive) return null;
  try {
    final response = await http
        .post(
          Uri.parse('${AuthConfig.apiBase}/v1/route'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'originLat': from.latitude,
            'originLng': from.longitude,
            'destLat': to.latitude,
            'destLng': to.longitude,
            'mode': 'DRIVE',
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final minutes = decoded['minutes'];
    if (minutes is! int || minutes < 1) return null;
    return minutes;
  } catch (_) {
    return null;
  }
}
