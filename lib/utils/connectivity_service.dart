import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  /// Devuelve true si parece haber internet real.
  /// - En móvil: Connectivity + lookup DNS (más fiable)
  /// - En web: solo Connectivity (lookup no aplica)
  static Future<bool> hasInternet() async {
    final connectivity = await Connectivity().checkConnectivity();

    final hasNetwork = connectivity != ConnectivityResult.none;
    if (!hasNetwork) return false;

    if (kIsWeb) {
      // En web no hacemos DNS lookup
      return true;
    }

    try {
      final result = await InternetAddress.lookup('example.com')
          .timeout(const Duration(milliseconds: 900));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
