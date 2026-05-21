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

/// Pantalla principal del panel de administración.

/// Desde aquí el administrador puede acceder
/// a todas las funciones principales del sistema.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  /// Repositorio encargado de gestionar las notificaciones.
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  /// Evita mostrar varias veces las notificaciones iniciales.
  bool _startupNotificationsShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Muestra las notificaciones pendientes
    // una única vez al iniciar la pantalla.
    if (!_startupNotificationsShown) {
      _startupNotificationsShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStartupSnackbars();
      });
    }
  }

  /// Muestra mensajes rápidos con las últimas notificaciones sin leer.
  Future<void> _showStartupSnackbars() async {
    try {
      // Obtiene un máximo de 3 notificaciones pendientes.
      final unread = await _notificationsRepo.fetchUnreadForStartup(limit: 3);

      if (!mounted || unread.isEmpty) return;

      // Si hay más de 3 notificaciones,
      // se muestra únicamente un resumen.
      if (unread.length > 3) {
        AppSnackbar.show(
          context,
          'Tienes ${unread.length} notificaciones nuevas',
        );
        return;
      }

      // Muestra cada notificación individualmente.
      for (final n in unread) {
        if (!mounted) return;

        AppSnackbar.show(
          context,
          '${n.title}: ${n.body}',
        );

        await Future.delayed(const Duration(milliseconds: 2300));
      }
    } catch (_) {
      // No se bloquea la aplicación si ocurre un error.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usuario autenticado actualmente.
    final user = FirebaseAuth.instance.currentUser;

    /// Stream que escucha cambios en el documento
    /// del usuario administrador en Firestore.
    final Stream<DocumentSnapshot<Map<String, dynamic>>>? userDocStream =
        (user == null)
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots();

    return Scaffold(
      appBar: AppBar(
        // Nombre mostrado en la parte superior.
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userDocStream,
          builder: (context, snap) {
            final data = snap.data?.data();

            // Nombre almacenado en Firestore.
            final name = (data?['name'] as String?)?.trim();

            // Texto mostrado si no existe nombre.
            final displayName =
                (name != null && name.isNotEmpty)
                    ? name
                    : 'Administrador';

            return Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),

        actions: [
          /// Botón para acceder a la vista de trabajador.
          IconButton(
            tooltip: 'Vista trabajador',
            icon: const Icon(Icons.switch_account),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const WorkerHome(
                    launchedFromAdmin: true,
                  ),
                ),
              );
            },
          ),

          /// Icono de notificaciones con contador dinámico.
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

                  // Contador rojo de notificaciones sin leer.
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
                          borderRadius: BorderRadius.all(
                            Radius.circular(10),
                          ),
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

          /// Botón para cerrar sesión.
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
            /// Detecta si la pantalla es ancha
            /// para adaptar el diseño.
            final isWide = constraints.maxWidth >= 900;

            /// Espaciado horizontal adaptable.
            final horizontalPadding = isWide ? 24.0 : 16.0;

            /// Anchura máxima del contenido.
            final maxContentWidth = isWide ? 1100.0 : 620.0;

            /// Lista de accesos rápidos del panel administrador.
            final items = [
              _AdminActionItem(
                title: 'Gestionar empleados',
                subtitle: 'Alta, edición y baja de empleados',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UsersPage(),
                    ),
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
                subtitle:
                    'Revisar justificantes subidos por los empleados',
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
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxContentWidth,
                    ),

                    // Diseño adaptativo según el tamaño de pantalla.
                    child: isWide
                        ? Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
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

                              // Vista en cuadrícula para pantallas grandes.
                              GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 18,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: 1.9,
                                ),
                                itemBuilder: (context, index) {
                                  return _AdminDashboardCard(
                                    item: items[index],
                                  );
                                },
                              ),
                            ],
                          )

                        // Vista vertical para móviles.
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),

                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 14,
                                  ),
                                  child: _AdminDashboardCard(
                                    item: item,
                                  ),
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

/// Modelo auxiliar para representar
/// cada opción del panel de administración.
class _AdminActionItem {
  /// Título principal de la opción.
  final String title;

  /// Descripción breve de la funcionalidad.
  final String subtitle;

  /// Icono mostrado en la tarjeta.
  final IconData icon;

  /// Acción ejecutada al pulsar la tarjeta.
  final VoidCallback onTap;

  const _AdminActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

/// Tarjeta visual utilizada en el panel administrador.
class _AdminDashboardCard extends StatelessWidget {
  /// Información asociada a la tarjeta.
  final _AdminActionItem item;

  const _AdminDashboardCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,

      // Bordes redondeados de la tarjeta.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),

      child: InkWell(
        onTap: item.onTap,

        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Row(
            children: [
              // Contenedor del icono principal.
              Container(
                width: 68,
                height: 68,

                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(16),
                ),

                child: Icon(
                  item.icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),

              const SizedBox(width: 18),

              // Información textual de la tarjeta.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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

              // Flecha decorativa lateral.
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