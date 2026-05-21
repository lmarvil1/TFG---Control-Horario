import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio encargado de comprobar el estado de conectividad.

/// Permite verificar si el dispositivo dispone de acceso
/// a internet antes de realizar operaciones de red.
class ConnectivityService {

  /// Comprueba si existe conexión real a internet.
  
  /// Funcionamiento:
  /// - En dispositivos móviles:
  ///   combina la comprobación de conectividad con una verificación DNS.
  
  /// - En entorno web:
  ///   únicamente utiliza Connectivity, ya que el lookup DNS
  ///   no está disponible.
  
  /// Retorna:
  /// - true si existe conexión funcional
  /// - false en caso contrario
  static Future<bool> hasInternet() async {

    // Obtiene el estado actual de conectividad del dispositivo
    final connectivity =
        await Connectivity().checkConnectivity();

    final hasNetwork =
        !connectivity.contains(
          ConnectivityResult.none,
        );
        
    // Si no existe ninguna red disponible
    if (!hasNetwork) return false;

    // En web no se realiza verificación DNS
    if (kIsWeb) {
      return true;
    }

    try {

      // Verificación adicional mediante resolución DNS
      final result = await InternetAddress
          .lookup('example.com')
          .timeout(
            const Duration(milliseconds: 900),
          );

      return result.isNotEmpty &&
          result.first.rawAddress.isNotEmpty;

    } catch (_) {

      // Si falla la resolución DNS,
      // se considera que no hay conexión real
      return false;
    }
  }
}