import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'notifications_repository.dart';

/// Modelo que representa una nómina subida al sistema.
class PayrollItem {
  /// Identificador del documento en Firestore.
  final String id;

  /// Identificador del empleado al que pertenece la nómina.
  final String employeeId;

  /// Nombre del empleado.
  final String employeeName;

  /// Año correspondiente a la nómina.
  final int year;

  /// Mes correspondiente a la nómina.
  final int month;

  /// Texto descriptivo del periodo de la nómina.
  final String periodLabel;

  /// Nombre original del archivo.
  final String fileName;

  /// URL de descarga del archivo almacenado en Firebase Storage.
  final String downloadUrl;

  /// Ruta interna del archivo dentro de Firebase Storage.
  final String storagePath;

  /// Fecha de subida del archivo.
  final DateTime? uploadedAt;

  /// UID del usuario que subió la nómina.
  final String? uploadedBy;

  const PayrollItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.year,
    required this.month,
    required this.periodLabel,
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  /// Crea una instancia de PayrollItem a partir de un documento de Firestore.
  factory PayrollItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return PayrollItem(
      id: doc.id,
      employeeId: (data['employeeId'] as String?)?.trim() ?? '',
      employeeName: (data['employeeName'] as String?)?.trim() ?? '',
      year: (data['year'] as num?)?.toInt() ?? 0,
      month: (data['month'] as num?)?.toInt() ?? 0,
      periodLabel: (data['periodLabel'] as String?)?.trim() ?? '',
      fileName: (data['fileName'] as String?)?.trim() ?? '',
      downloadUrl: (data['downloadUrl'] as String?)?.trim() ?? '',
      storagePath: (data['storagePath'] as String?)?.trim() ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      uploadedBy: (data['uploadedBy'] as String?)?.trim(),
    );
  }
}

/// Repositorio encargado de gestionar las nóminas.
/// Permite consultar, filtrar y subir nóminas, almacenando el archivo
/// en Firebase Storage y sus metadatos en Firestore.
class PayrollsRepository {
  /// Instancia de Firestore.
  final _db = FirebaseFirestore.instance;

  /// Instancia de Firebase Storage.
  final _storage = FirebaseStorage.instance;

  /// Instancia de Firebase Auth para identificar al usuario que sube archivos.
  final _auth = FirebaseAuth.instance;

  /// Repositorio utilizado para notificar al trabajador cuando se sube una nómina.
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  /// Referencia a la colección de nóminas.
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('payrolls');

  /// Limpia el nombre del archivo para evitar caracteres no válidos en Storage.
  String _safeFileName(String filename) {
    return filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
  }

  /// Genera una etiqueta legible para el periodo de la nómina.
  String _periodLabel(int month, int year) {
    const names = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return '${names[month]} $year';
  }

  /// Busca el UID del usuario asociado a un employeeId.
  /// Se utiliza para enviar una notificación al trabajador correspondiente.
  Future<String?> _findUserUidByEmployeeId(String employeeId) async {
    final snap = await _db
        .collection('users')
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Devuelve las nóminas visibles para administración.
  /// Permite filtrar por empleado, mes y año.
  Stream<List<PayrollItem>> streamAdminPayrolls({
    String? employeeId,
    int? month,
    int? year,
  }) {
    Query<Map<String, dynamic>> q = _col;

    // Filtro opcional por empleado
    if (employeeId != null && employeeId.trim().isNotEmpty) {
      q = q.where('employeeId', isEqualTo: employeeId.trim());
    }

    // Filtro opcional por año
    if (year != null) {
      q = q.where('year', isEqualTo: year);
    }

    // Filtro opcional por mes
    if (month != null) {
      q = q.where('month', isEqualTo: month);
    }

    // Orden por fecha de subida
    q = q.orderBy('uploadedAt', descending: true);

    return q.snapshots().map(
          (snap) => snap.docs.map(PayrollItem.fromDoc).toList(),
        );
  }

  /// Devuelve las nóminas de un empleado concreto.
  /// Permite aplicar filtros opcionales por mes y año.
  Stream<List<PayrollItem>> streamEmployeePayrolls({
    required String employeeId,
    int? month,
    int? year,
  }) {
    Query<Map<String, dynamic>> q =
        _col.where('employeeId', isEqualTo: employeeId.trim());

    if (year != null) {
      q = q.where('year', isEqualTo: year);
    }

    if (month != null) {
      q = q.where('month', isEqualTo: month);
    }

    q = q.orderBy('uploadedAt', descending: true);

    return q.snapshots().map(
          (snap) => snap.docs.map(PayrollItem.fromDoc).toList(),
        );
  }

  /// Sube una nómina al sistema.
  /// Proceso:
  /// 1. Genera una ruta segura para el archivo
  /// 2. Sube el PDF a Firebase Storage
  /// 3. Guarda los metadatos en Firestore
  /// 4. Notifica al trabajador correspondiente
  Future<void> uploadPayroll({
    required String employeeId,
    required String employeeName,
    required int month,
    required int year,
    required String filename,
    required Uint8List bytes,
  }) async {
    final safeName = _safeFileName(filename);
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Ruta interna del archivo dentro de Firebase Storage
    final path =
        'payrolls/$employeeId/$year/${month.toString().padLeft(2, '0')}_${ts}_$safeName';

    final ref = _storage.ref().child(path);

    // Subida del archivo PDF a Storage
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    // URL de descarga asociada al archivo subido
    final downloadUrl = await ref.getDownloadURL();

    // Etiqueta textual del periodo (ej: Mayo 2026)
    final periodLabel = _periodLabel(month, year);

    // Registro de metadatos de la nómina en Firestore
    final docRef = await _col.add({
      'employeeId': employeeId.trim(),
      'employeeName': employeeName.trim(),
      'year': year,
      'month': month,
      'periodLabel': periodLabel,
      'fileName': filename,
      'downloadUrl': downloadUrl,
      'storagePath': path,
      'uploadedAt': FieldValue.serverTimestamp(),
      'uploadedBy': _auth.currentUser?.uid,
    });

    // Notificación al trabajador cuando la nómina queda disponible
    final workerUid = await _findUserUidByEmployeeId(employeeId);

    if (workerUid != null && workerUid.trim().isNotEmpty) {
      await _notificationsRepo.createNotification(
        recipientUid: workerUid,
        title: 'Nueva nómina disponible',
        body: 'Ya puedes consultar tu nómina de $periodLabel.',
        type: 'payroll_uploaded',
        relatedId: docRef.id,
        relatedType: 'payroll',
      );
    }
  }
}