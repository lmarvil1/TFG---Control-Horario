import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio encargado de obtener el rol de un usuario desde Firestore.
/// Agrupa el acceso a Firestore para obtener el rol del usuario.
/// De esta forma se evita repetir código y se facilita el mantenimiento.

class UserRoleService {

  /// Obtiene el rol de un usuario a partir de su identificador (uid).
  /// Parámetro:
  /// - uid: identificador único del usuario en Firebase
  /// Devuelve:
  /// - String: rol del usuario (por defecto 'worker' si no existe)

  static Future<String> getRole(String uid) async {
    // Accede al documento del usuario en la colección 'users'
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    // Extrae los datos del documento
    final data = doc.data();

    // Si no existen datos, se devuelve el rol por defecto
    if (data == null) return 'worker';

    // Se obtiene el campo 'role', se limpia (trim) y se devuelve.
    // Si no existe o es nulo, se utiliza 'worker' como valor por defecto.
    return (data['role'] as String?)?.trim() ?? 'worker';
  }
}