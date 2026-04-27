import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class JustificationsRepository {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('absence_justifications');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMine(String uid) {
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

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
    final safeName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final path =
        'justifications/$uid/${now.millisecondsSinceEpoch}_$safeName';

    final storageRef = _storage.ref().child(path);

    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    final downloadUrl = await storageRef.getDownloadURL();

    await _col.add({
      'uid': uid,
      'employeeId': employeeId,
      'filename': filename,
      'storagePath': path,
      'downloadUrl': downloadUrl,
      'contentType': contentType,
      'reason': reason.trim(),
      'date': Timestamp.fromDate(
        DateTime(date.year, date.month, date.day),
      ),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}