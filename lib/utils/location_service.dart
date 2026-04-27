import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Devuelve un map listo para Firestore, o null si no se pudo.
  /// {lat, lng, accuracy, capturedAtMs}
  static Future<Map<String, dynamic>?> tryGetLocationForPunch({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        debugPrint('LocationService: GPS desactivado');
        return null;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        debugPrint('LocationService: permiso denegado');
        return null;
      }
      if (perm == LocationPermission.deniedForever) {
        debugPrint('LocationService: permiso denegado permanentemente');
        return null;
      }

      // 1) Intento principal: posición actual (puede tardar)
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: timeout,
        );
      } on TimeoutException {
        debugPrint('LocationService: timeout getCurrentPosition');
        pos = null;
      } catch (e) {
        debugPrint('LocationService: error getCurrentPosition: $e');
        pos = null;
      }

      // 2) Fallback: última conocida (muchas veces existe aunque no haya fix aún)
      pos ??= await Geolocator.getLastKnownPosition();

      if (pos == null) {
        debugPrint('LocationService: sin ubicación (pos=null)');
        return null;
      }

      return {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'capturedAtMs': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      debugPrint('LocationService: error general: $e');
      return null;
    }
  }
}