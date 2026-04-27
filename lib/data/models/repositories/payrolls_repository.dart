import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'notifications_repository.dart';

class PayrollItem {
  final String id;
  final String employeeId;
  final String employeeName;
  final int year;
  final int month;
  final String periodLabel;
  final String fileName;
  final String downloadUrl;
  final String storagePath;
  final DateTime? uploadedAt;
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

class PayrollsRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('payrolls');

  String _safeFileName(String filename) {
    return filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
  }

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

  Future<String?> _findUserUidByEmployeeId(String employeeId) async {
    final snap = await _db
        .collection('users')
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Stream<List<PayrollItem>> streamAdminPayrolls({
    String? employeeId,
    int? month,
    int? year,
  }) {
    Query<Map<String, dynamic>> q = _col;

    if (employeeId != null && employeeId.trim().isNotEmpty) {
      q = q.where('employeeId', isEqualTo: employeeId.trim());
    }
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
    final path =
        'payrolls/$employeeId/$year/${month.toString().padLeft(2, '0')}_${ts}_$safeName';

    final ref = _storage.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final downloadUrl = await ref.getDownloadURL();
    final periodLabel = _periodLabel(month, year);

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