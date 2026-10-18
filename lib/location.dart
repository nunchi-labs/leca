import 'package:geolocator/geolocator.dart';

class TripFix {
  const TripFix({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Device fix for a live trip share. Tests inject [override].
class TripLocation {
  static Future<TripFix?> Function()? override;

  static Future<TripFix?> current() async {
    final hooked = override;
    if (hooked != null) return hooked();
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return TripFix(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on Object catch (_) {
      return null;
    }
  }
}
