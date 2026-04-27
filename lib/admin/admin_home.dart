import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../notifications/notifications_page.dart';
import '../utils/app_snackbar.dart';
import 'users_page.dart';
import 'assign_employee_page.dart';
import 'employee_punches_page.dart';
import 'admin_incidents_page.dart';
import 'admin_vacations_page.dart';
import 'admin_justifications_page.dart';
import 'admin_payrolls_page.dart';
import '../worker/worker_home.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final NotificationsRepository _notificationsRepo = NotificationsRepository();
  bool _startupNotificationsShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_startupNotificationsShown) {
      _startupNotificationsShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartupSnackbars();
      });
    }
  }

  Future<void> _showStartupSnackbars() async {
    try {
      final unread = await _notificationsRepo.fetchUnreadForStartup(limit: 3);
      if (!mounted || unread.isEmpty) return;

      if (unread.length > 3) {
        AppSnackbar.show(
          context,
          'Tienes ${unread.length} notificaciones nuevas',
        );
        return;
      }

      for (final n in unread) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          '${n.title}: ${n.body}',
        );
        await Future.delayed(const Duration(milliseconds: 2300));
      }
    } catch (_) {
      // No bloqueamos la pantalla si falla esto.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final Stream<DocumentSnapshot<Map<String, dynamic>>>? userDocStream =
        (user == null)
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snap) {
            final data = snap.data?.data();
            final name = (data?['name'] as String?)?.trim();
            final displayName =
                (name != null && name.isNotEmpty) ? name : 'Administrador';

            return Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Vista trabajador',
            icon: const Icon(Icons.switch_account),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerHome(launchedFromAdmin: true),
                ),
              );
            },
          ),
          StreamBuilder<int>(
            stream: _notificationsRepo.streamUnreadCount(),
            builder: (context, snap) {
              final unreadCount = snap.data ?? 0;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notificaciones',
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 24.0 : 16.0;
            final maxContentWidth = isWide ? 1100.0 : 620.0;

            final items = [
              _AdminActionItem(
                title: 'Gestionar empleados',
                subtitle: 'Alta, edición y baja de empleados',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsersPage()),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Usuarios y roles',
                subtitle: 'Vincular empleados y asignar permisos',
                icon: Icons.manage_accounts,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AssignEmployeePage(),
                    ),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Ver fichajes por empleado',
                subtitle: 'Consultar historial y exportaciones',
                icon: Icons.list_alt,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmployeePunchesPage(),
                    ),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Gestionar incidencias',
                subtitle: 'Aprobar, rechazar y revisar incidencias',
                icon: Icons.report_problem,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminIncidentsPage(),
                    ),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Gestionar vacaciones',
                subtitle: 'Solicitudes, aprobación y calendario',
                icon: Icons.beach_access,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminVacationsPage(),
                    ),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Gestionar justificantes',
                subtitle: 'Revisar justificantes subidos por los empleados',
                icon: Icons.description,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminJustificationsPage(),
                    ),
                  );
                },
              ),
              _AdminActionItem(
                title: 'Gestionar nóminas',
                subtitle: 'Subir, consultar y descargar nóminas',
                icon: Icons.payments,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminPayrollsPage(),
                    ),
                  );
                },
              ),
            ];

            return SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: isWide
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Panel de administración',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Accede rápidamente a las funciones principales del sistema.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 24),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: 1.9,
                                ),
                                itemBuilder: (context, index) {
                                  return _AdminDashboardCard(item: items[index]);
                                },
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _AdminDashboardCard(item: item),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _AdminActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _AdminDashboardCard extends StatelessWidget {
  final _AdminActionItem item;

  const _AdminDashboardCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}