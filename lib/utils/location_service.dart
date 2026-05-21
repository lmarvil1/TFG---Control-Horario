import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio encargado de gestionar la obtención de la ubicación del dispositivo.

/// Se utiliza principalmente durante el registro de fichajes
/// para almacenar información de localización.
class LocationService {

  /// Intenta obtener la ubicación actual del dispositivo.
  /// Retorna un Map preparado para almacenarse en Firestore
  /// con la siguiente estructura:
  /// {
  ///   lat,
  ///   lng,
  ///   accuracy,
  ///   capturedAtMs
  /// }

  /// Si la ubicación no puede obtenerse, retorna null.
  static Future<Map<String, dynamic>?> tryGetLocationForPunch({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {

      // Comprueba si el servicio de ubicación del dispositivo está activado
      final enabled = await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        debugPrint('LocationService: GPS desactivado');
        return null;
      }

      // Comprueba el estado actual de permisos
      LocationPermission perm = await Geolocator.checkPermission();

      // Solicita permisos si todavía no se han concedido
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      // Si el usuario deniega el permiso, se cancela el proceso
      if (perm == LocationPermission.denied) {
        debugPrint('LocationService: permiso denegado');
        return null;
      }

      // Si el permiso ha sido denegado permanentemente,
      // la aplicación ya no puede volver a solicitarlo automáticamente
      if (perm == LocationPermission.deniedForever) {
        debugPrint(
          'LocationService: permiso denegado permanentemente',
        );
        return null;
      }

      // Primer intento:
      // Obtención de la posición actual con alta precisión
      Position? pos;

      try {
        pos = await Geolocator.getCurrentPosition(

          // Configuración de precisión y tiempo máximo de espera
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeout,
          ),
        );

      // Control del tiempo máximo de espera
      } on TimeoutException {
        debugPrint(
          'LocationService: timeout getCurrentPosition',
        );

        pos = null;

      } catch (e) {

        // Gestión de errores durante la obtención
        debugPrint(
          'LocationService: error getCurrentPosition: $e',
        );

        pos = null;
      }

      // Segundo intento (fallback):
      // Recupera la última ubicación conocida del dispositivo
      pos ??= await Geolocator.getLastKnownPosition();

      // Si sigue sin existir ubicación disponible
      if (pos == null) {
        debugPrint(
          'LocationService: sin ubicación (pos=null)',
        );

        return null;
      }

      // Devuelve la información preparada para Firestore
      return {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,

        // Marca temporal de captura en milisegundos
        'capturedAtMs':
            DateTime.now().millisecondsSinceEpoch,
      };

    } catch (e) {

      // Gestión de errores generales inesperados
      debugPrint('LocationService: error general: $e');

      return null;
    }
  }
}