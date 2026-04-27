import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoleService {
  static Future<String> getRole(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return 'worker';
    return (data['role'] as String?)?.trim() ?? 'worker';
  }
}