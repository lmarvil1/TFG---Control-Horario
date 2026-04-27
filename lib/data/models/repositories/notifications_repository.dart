import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppNotification {
  final String id;
  final String recipientUid;
  final String title;
  final String body;
  final String type;
  final DateTime? createdAt;
  final DateTime? readAt;
  final String? relatedId;
  final String? relatedType;
  final String? senderUid;

  const AppNotification({
    required this.id,
    required this.recipientUid,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.readAt,
    required this.relatedId,
    required this.relatedType,
    required this.senderUid,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      recipientUid: (data['recipientUid'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      type: (data['type'] as String?)?.trim() ?? 'general',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      relatedId: (data['relatedId'] as String?)?.trim(),
      relatedType: (data['relatedType'] as String?)?.trim(),
      senderUid: (data['senderUid'] as String?)?.trim(),
    );
  }
}

class NotificationsRepository {
  NotificationsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado');
    }
    return user.uid;
  }

  Stream<List<AppNotification>> streamMyNotifications() {
    return _col
        .where('recipientUid', isEqualTo: _uid)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(AppNotification.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  Stream<int> streamUnreadCount() {
    return _col
        .where('recipientUid', isEqualTo: _uid)
        .where('readAt', isNull: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<List<AppNotification>> fetchUnreadForStartup({
    int limit = 3,
  }) async {
    final snap = await _col
        .where('recipientUid', isEqualTo: _uid)
        .where('readAt', isNull: true)
        .get();

    final items = snap.docs.map(AppNotification.fromDoc).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    return items.take(limit).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead() async {
    final snap = await _col
        .where('recipientUid', isEqualTo: _uid)
        .where('readAt', isNull: true)
        .get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _col.doc(notificationId).delete();
  }

  Future<void> deleteNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    final batch = _db.batch();
    for (final id in notificationIds) {
      batch.delete(_col.doc(id));
    }
    await batch.commit();
  }

  Future<void> deleteAllMyNotifications() async {
    final snap = await _col.where('recipientUid', isEqualTo: _uid).get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> createNotification({
    required String recipientUid,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? relatedType,
    String? senderUid,
  }) async {
    await _col.add({
      'recipientUid': recipientUid.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'readAt': null,
      'relatedId': relatedId,
      'relatedType': relatedType,
      'senderUid': senderUid ?? _auth.currentUser?.uid,
    });
  }
}