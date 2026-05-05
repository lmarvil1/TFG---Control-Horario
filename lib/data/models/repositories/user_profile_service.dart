import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio encargado de la gestión del perfil de usuario.
/// Proporciona métodos para:
/// - Garantizar que existe un documento de usuario en Firestore
/// - Almacenar y recuperar el rol del usuario en caché local

class UserProfileService {
  // Instancia de acceso a la base de datos Firestore
  static final _db = FirebaseFirestore.instance;

  /// Asegura que el usuario autenticado tenga un perfil en Firestore.
  /// Si el documento no existe, se crea con valores por defecto.
  /// Parámetro:
  /// - defaultRole: rol asignado al usuario en caso de creación inicial, que por defecto es 'worker'.

  static Future<void> ensureProfileExists({
    String defaultRole = 'worker',
  }) async {
    // Obtiene el usuario actualmente autenticado
    final user = FirebaseAuth.instance.currentUser;

    // Si no hay usuario autenticado, no se realiza ninguna acción
    if (user == null) return;

    // Referencia al documento del usuario en la colección 'users'
    final ref = _db.collection('users').doc(user.uid);

    // Obtiene el documento desde Firestore
    final snap = await ref.get();

    // Si el documento no existe, se crea con valores iniciales
    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'role': defaultRole,
        'name': '',
        'employeeId': '',
        'department': '',
        'active': true,

        // Campos relacionados con acceso de inspección
        'inspectionAccessEnabled': false,
        'inspectionAccessUntil': null,

        // Fecha de creación generada en servidor
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Genera la clave utilizada para almacenar el rol en caché local.
  /// Se construye usando el identificador del usuario para evitar conflictos
  /// entre múltiples usuarios en el mismo dispositivo.
  static String _roleKey(String uid) => 'role_$uid';

  /// Guarda el rol del usuario en almacenamiento local (SharedPreferences).
  /// Esto permite acceder al rol sin necesidad de consultar Firestore,
  /// mejorando el rendimiento y la disponibilidad offline.
  static Future<void> cacheRole(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey(uid), role);
  }

  /// Recupera el rol almacenado en caché local.
  /// Devuelve:
  /// - String? → rol guardado o null si no existe
  static Future<String?> getCachedRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey(uid));
  }
}