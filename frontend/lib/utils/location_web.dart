// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

Future<Map<String, double>> getCurrentLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition();
    final lat = position.coords?.latitude?.toDouble() ?? 0.0;
    final lng = position.coords?.longitude?.toDouble() ?? 0.0;
    return {
      'latitude': lat,
      'longitude': lng,
    };
  } catch (e) {
    throw Exception('Failed to get location: $e');
  }
}
