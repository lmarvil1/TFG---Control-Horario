import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> ensureProfileExists({
    String defaultRole = 'worker',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'role': defaultRole,
        'name': '',
        'employeeId': '',
        'department': '',
        'active': true,
        'inspectionAccessEnabled': false,
        'inspectionAccessUntil': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static String _roleKey(String uid) => 'role_$uid';

  static Future<void> cacheRole(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey(uid), role);
  }

  static Future<String?> getCachedRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey(uid));
  }
}