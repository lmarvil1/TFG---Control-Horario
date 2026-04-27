import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PunchService {
  static Future<void> punch(String type) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('punches')
        .add({
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
