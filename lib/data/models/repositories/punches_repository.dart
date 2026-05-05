import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tfg_app/utils/location_service.dart';

/// Repositorio encargado de gestionar los fichajes de los empleados.
/// Permite:
/// - Registrar entradas y salidas (fichajes)
/// - Consultar el historial en tiempo real
/// - Obtener el último tipo de fichaje realizado
class PunchesRepository {

  /// Devuelve la referencia a la subcolección de fichajes de un empleado.
  /// Estructura en Firestore:
  /// punches/{employeeId}/items/{punchId}
  CollectionReference<Map<String, dynamic>> _itemsCol(String employeeId) {
    return FirebaseFirestore.instance
        .collection('punches')
        .doc(employeeId)
        .collection('items');
  }

  /// Registra un nuevo fichaje (entrada o salida).
  /// Parámetros:
  /// - employeeId: identificador del empleado
  /// - type: tipo de fichaje ("in" o "out")
  /// Devuelve:
  /// - Referencia al documento creado en Firestore
  
  /// Incluye, si es posible, la localización del dispositivo en el momento
  /// del fichaje.
  Future<DocumentReference<Map<String, dynamic>>> addPunch({
    required String employeeId,
    required String type, // "in" o "out"
  }) async {
    Map<String, dynamic>? location;

    try {
      // Intenta obtener la localización del dispositivo con un tiempo límite
      final loc = await LocationService.tryGetLocationForPunch(
        timeout: const Duration(seconds: 6),
      );

      // Si se obtiene correctamente, se formatea para Firestore
      if (loc != null) {
        location = {
          'lat': loc['lat'],
          'lng': loc['lng'],
          'accuracy': loc['accuracy'],
          'capturedAt': Timestamp.fromMillisecondsSinceEpoch(
            loc['capturedAtMs'] as int,
          ),
        };
      }
    } catch (e) {
      // Si falla la localización, no se bloquea el fichaje
      debugPrint('Location not available: $e');
    }

    // Datos del fichaje
    final data = <String, dynamic>{
      'type': type,
      'at': Timestamp.fromDate(DateTime.now()), // momento del fichaje
      'syncedAt': FieldValue.serverTimestamp(), // sincronización con servidor
      'source': 'mobile', // origen del fichaje
      'locationOk': location != null, // indica si se obtuvo localización
      if (location != null) 'location': location,
    };

    // Inserta el fichaje en Firestore
    return _itemsCol(employeeId).add(data);
  }

  /// Devuelve un flujo en tiempo real con los fichajes del empleado.
  /// Parámetros:
  /// - employeeId: identificador del empleado
  /// - includeMetadata: indica si se incluyen cambios de metadatos
  /// Los resultados se ordenan por fecha descendente.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamPunches(
    String employeeId, {
    bool includeMetadata = false,
  }) {
    return _itemsCol(employeeId)
        .orderBy('at', descending: true)
        .snapshots(includeMetadataChanges: includeMetadata);
  }

  /// Obtiene el tipo del último fichaje realizado.
  /// Devuelve:
  /// - "in", "out" o null si no existen registros
  /// Se utiliza para determinar si el siguiente fichaje debe ser entrada o salida.
  Future<String?> getLastType(String employeeId) async {
    final q = await _itemsCol(employeeId)
        .orderBy('at', descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    return q.docs.first.data()['type'] as String?;
  }
}