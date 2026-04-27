import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tfg_app/utils/location_service.dart';

class PunchesRepository {
  CollectionReference<Map<String, dynamic>> _itemsCol(String employeeId) {
    return FirebaseFirestore.instance
        .collection('punches')
        .doc(employeeId)
        .collection('items');
  }

  /// ✅ Devuelve la referencia creada para poder detectar si confirmó rápido
  Future<DocumentReference<Map<String, dynamic>>> addPunch({
    required String employeeId,
    required String type, // "in" o "out"
  }) async {
    Map<String, dynamic>? location;

    try {
      final loc = await LocationService.tryGetLocationForPunch(
        timeout: const Duration(seconds: 6),
      );

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
      debugPrint('Location not available: $e');
    }

    final data = <String, dynamic>{
      'type': type,
      'at': Timestamp.fromDate(DateTime.now()),
      'syncedAt': FieldValue.serverTimestamp(),
      'source': 'mobile',
      'locationOk': location != null,
      if (location != null) 'location': location,
    };

    return _itemsCol(employeeId).add(data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPunches(
    String employeeId, {
    bool includeMetadata = false,
  }) {
    return _itemsCol(employeeId)
        .orderBy('at', descending: true)
        .snapshots(includeMetadataChanges: includeMetadata);
  }

  Future<String?> getLastType(String employeeId) async {
    final q = await _itemsCol(employeeId)
        .orderBy('at', descending: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first.data()['type'] as String?;
  }
}
