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

class RouterPage extends StatelessWidget {
  const RouterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<Widget>(
          future: _resolveHome(user.uid),
          builder: (context, homeSnap) {
            if (homeSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return homeSnap.data ?? const WorkerHome();
          },
        );
      },
    );
  }

  Future<Widget> _resolveHome(String uid) async {
    try {
      await UserProfileService.ensureProfileExists(defaultRole: UserRoles.worker);
    } catch (_) {
      // No bloqueamos la navegación si falla esto.
    }

    String role;
    try {
      role = await UserRoleService.getRole(uid);
      await UserProfileService.cacheRole(uid, role);
    } catch (_) {
      role = (await UserProfileService.getCachedRole(uid)) ?? UserRoles.worker;
    }

    switch (role) {
      case UserRoles.admin:
        return const AdminHome();

      case UserRoles.worker:
        return const WorkerHome();

      case UserRoles.rlt:
        // Temporalmente usamos WorkerHome hasta crear RltHome.
        return const RltHome();

      case UserRoles.inspector:
        // Temporalmente usamos WorkerHome hasta crear InspectorHome.
        return const InspectorHome();

      default:
        return const WorkerHome();
    }
  }
}