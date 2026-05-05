import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modelo que representa una notificación interna de la aplicación.
class AppNotification {
  /// Identificador del documento en Firestore.
  final String id;

  /// UID del usuario destinatario de la notificación.
  final String recipientUid;

  /// Título de la notificación.
  final String title;

  /// Contenido principal de la notificación.
  final String body;

  /// Tipo de notificación.
  final String type;

  /// Fecha de creación de la notificación.
  final DateTime? createdAt;

  /// Fecha de lectura.
  /// Si es null, la notificación se considera no leída.
  final DateTime? readAt;

  /// Identificador del elemento relacionado con la notificación.
  final String? relatedId;

  /// Tipo de elemento relacionado.
  final String? relatedType;

  /// UID del usuario que genera la notificación, si existe.
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

  /// Indica si la notificación ya ha sido leída.
  bool get isRead => readAt != null;

  /// Crea una instancia de AppNotification desde un documento de Firestore.
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

/// Repositorio encargado de gestionar las notificaciones internas.
/// Centraliza la creación, consulta, marcado como leído y eliminación
/// de notificaciones almacenadas en Firestore.
class NotificationsRepository {
  NotificationsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Instancia de Firestore utilizada por el repositorio.
  final FirebaseFirestore _db;

  /// Instancia de Firebase Auth utilizada para identificar al usuario actual.
  final FirebaseAuth _auth;

  /// Referencia a la colección de notificaciones.
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  /// UID del usuario autenticado.
  /// Si no existe una sesión activa, se lanza un error de estado.
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No hay usuario autenticado');
    }
    return user.uid;
  }

  /// Devuelve en tiempo real las notificaciones del usuario autenticado.
  /// Se ordenan por fecha de creación, mostrando primero las más recientes.
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

  /// Devuelve en tiempo real el número de notificaciones no leídas.
  Stream<int> streamUnreadCount() {
    return _col
        .where('recipientUid', isEqualTo: _uid)
        .where('readAt', isNull: true)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Obtiene un número limitado de notificaciones no leídas al iniciar la app.
  /// Se utiliza para mostrar avisos iniciales sin cargar toda la colección.
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

  /// Marca una notificación como leída.
  Future<void> markAsRead(String notificationId) async {
    await _col.doc(notificationId).update({
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  /// Marca como leídas todas las notificaciones pendientes del usuario.
  /// Se utiliza una escritura por lotes para aplicar los cambios
  /// de forma agrupada.
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

  /// Elimina una notificación concreta.
  Future<void> deleteNotification(String notificationId) async {
    await _col.doc(notificationId).delete();
  }

  /// Elimina varias notificaciones mediante una escritura por lotes.
  Future<void> deleteNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;

    final batch = _db.batch();

    for (final id in notificationIds) {
      batch.delete(_col.doc(id));
    }

    await batch.commit();
  }

  /// Elimina todas las notificaciones del usuario autenticado.
  Future<void> deleteAllMyNotifications() async {
    final snap = await _col.where('recipientUid', isEqualTo: _uid).get();

    if (snap.docs.isEmpty) return;

    final batch = _db.batch();

    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  /// Crea una nueva notificación en Firestore.
  /// Permite asociar la notificación con otro elemento de la aplicación,
  /// como una solicitud de vacaciones o una justificación.
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