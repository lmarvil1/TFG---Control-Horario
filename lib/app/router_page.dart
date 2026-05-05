import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/login_page.dart';
import '../admin/admin_home.dart';
import '../worker/worker_home.dart';
import '../core/user_roles.dart';
import '../rlt/rlt_home.dart';
import '../inspector/inspector_home.dart';
import 'package:tfg_app/data/models/repositories/user_profile_service.dart';
import 'package:tfg_app/data/models/repositories/user_role_service.dart';

/// Página encargada de decidir qué pantalla debe mostrarse al usuario.
/// Esta clase actúa como punto de control inicial de la aplicación:
/// comprueba si existe una sesión activa y, en caso afirmativo,
/// redirige al usuario a la pantalla correspondiente según su rol.

class RouterPage extends StatelessWidget {
  const RouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Escucha en tiempo real los cambios de autenticación de Firebase.
      // Esto permite reaccionar automáticamente ante inicio o cierre de sesión.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        // Mientras se obtiene el estado de autenticación, se muestra
        // un indicador de carga para evitar mostrar una pantalla incorrecta.
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;

        // Si no hay usuario autenticado, se muestra la pantalla de login.
        if (user == null) return const LoginPage();

        return FutureBuilder<Widget>(
          // Resuelve de forma asíncrona la pantalla principal del usuario
          // en función de su identificador y su rol.
          future: _resolveHome(user.uid),
          builder: (context, homeSnap) {
            // Mientras se consulta el rol del usuario, se muestra
            // un indicador de carga.
            if (homeSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Si no se obtiene una pantalla concreta, se usa WorkerHome
            // como pantalla por defecto para mantener la navegación estable.
            return homeSnap.data ?? const WorkerHome();
          },
        );
      },
    );
  }

  /// Determina la pantalla principal que debe abrirse según el rol del usuario.
  /// Parámetro:
  /// - uid: identificador único del usuario autenticado en Firebase. 
  /// Devuelve:
  /// - Widget: pantalla principal correspondiente al rol del usuario.
  Future<Widget> _resolveHome(String uid) async {
    try {
      // Garantiza que el usuario tenga un perfil creado en Firestore.
      // Si no existe, se genera con el rol por defecto de trabajador.
      await UserProfileService.ensureProfileExists(
        defaultRole: UserRoles.worker,
      );
    } catch (_) {
      // Un fallo al crear o comprobar el perfil no debe impedir
      // que el usuario acceda a la aplicación.
    }

    String role;

    try {
      // Obtiene el rol actual del usuario desde el servicio correspondiente.
      role = await UserRoleService.getRole(uid);

      // Guarda el rol en caché para poder utilizarlo como respaldo
      // en caso de errores posteriores de conexión o lectura.
      await UserProfileService.cacheRole(uid, role);
    } catch (_) {
      // Si no se puede obtener el rol remoto, se intenta recuperar
      // el último rol almacenado localmente.
      role = (await UserProfileService.getCachedRole(uid)) ?? UserRoles.worker;
    }

    // Redirección del usuario a la pantalla correspondiente según su rol.
    switch (role) {
      case UserRoles.admin:
        return const AdminHome();

      case UserRoles.worker:
        return const WorkerHome();

      case UserRoles.rlt:
        return const RltHome();

      case UserRoles.inspector:
        return const InspectorHome();

      default:
        // Cualquier rol no reconocido se trata como trabajador
        // para evitar errores de navegación.
        return const WorkerHome();
    }
  }
}