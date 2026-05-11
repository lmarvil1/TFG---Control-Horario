import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Repositorio encargado de gestionar los justificantes de ausencia.
/// Permite:
/// - Subir archivos a Firebase Storage
/// - Registrar la información del justificante en Firestore
/// - Consultar justificantes del usuario
class JustificationsRepository {
  /// Instancia de Firestore
  final _db = FirebaseFirestore.instance;

  /// Instancia de Firebase Storage
  final _storage = FirebaseStorage.instance;

  /// Referencia a la colección donde se almacenan los justificantes
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('absence_justifications');

  /// Devuelve un flujo en tiempo real con los justificantes del usuario.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMine(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Sube un justificante de ausencia.
  Future<void> uploadJustification({
    required String uid,
    required String employeeId,
    required String filename,
    required Uint8List bytes,
    required String contentType,
    required String reason,
    required DateTime date,
  }) async {
    final now = DateTime.now();

    // BLOQUEAR FECHAS FUTURAS
    final selectedDateOnly = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final todayOnly = DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (selectedDateOnly.isAfter(todayOnly)) {
      throw Exception(
        'No se pueden subir justificantes de fechas futuras',
      );
    }

    // Limpia el nombre del archivo
    final safeName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');

    // Ruta del archivo
    final path =
        'justifications/$uid/${now.millisecondsSinceEpoch}_$safeName';

    final storageRef = _storage.ref().child(path);

    // Subida del archivo
    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    // URL descarga
    final downloadUrl = await storageRef.getDownloadURL();

    // Registro en Firestore
    await _col.add({
      'uid': uid,
      'employeeId': employeeId,
      'filename': filename,
      'storagePath': path,
      'downloadUrl': downloadUrl,
      'contentType': contentType,
      'reason': reason.trim(),

      // Solo fecha
      'date': Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      ),

      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}