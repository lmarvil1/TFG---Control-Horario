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
  /// Parámetro:
  /// - uid: identificador del usuario autenticado
  
  /// Los resultados se ordenan por fecha de creación descendente.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMine(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Sube un justificante de ausencia.
  /// Proceso:
  /// 1. Genera un nombre seguro para el archivo
  /// 2. Sube el archivo a Firebase Storage
  /// 3. Obtiene la URL de descarga
  /// 4. Guarda los metadatos en Firestore
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

    // Limpia el nombre del archivo para evitar caracteres no válidos
    final safeName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');

    // Ruta donde se almacenará el archivo en Firebase Storage
    final path =
        'justifications/$uid/${now.millisecondsSinceEpoch}_$safeName';

    final storageRef = _storage.ref().child(path);

    // Subida del archivo con su tipo de contenido
    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    // Obtención de la URL de descarga
    final downloadUrl = await storageRef.getDownloadURL();

    // Registro del justificante en Firestore
    await _col.add({
      'uid': uid,
      'employeeId': employeeId,
      'filename': filename,
      'storagePath': path,
      'downloadUrl': downloadUrl,
      'contentType': contentType,
      'reason': reason.trim(),

      // Se guarda solo la fecha (sin hora)
      'date': Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      ),

      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}