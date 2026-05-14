import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_incidents_page.dart';
import '../admin/admin_justifications_page.dart';
import '../admin/admin_vacations_page.dart';
import '../admin/employee_punches_page.dart';
import '../admin/users_page.dart';

class InspectorHome extends StatelessWidget {
  const InspectorHome({super.key});

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  bool _hasActiveInspectionAccess(Map<String, dynamic>? data) {
    final enabled = data?['inspectionAccessEnabled'] as bool? ?? false;
    final until = data?['inspectionAccessUntil'];

    if (!enabled) return false;

    if (until == null) return true;

    if (until is Timestamp) {
      return until.toDate().isAfter(DateTime.now());
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sesión cerrada')),
        body: const Center(
          child: Text('No hay ningún usuario autenticado.'),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data?.data();
        final hasAccess = _hasActiveInspectionAccess(data);

        if (!hasAccess) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Inspección - Acceso denegado'),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: _signOut,
                ),
              ],
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu acceso ha caducado.\n\n'
                  'Pide a un administrador que reactive el acceso.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }

        return const _InspectorPanel();
      },
    );
  }
}

class _InspectorPanel extends StatelessWidget {
  const _InspectorPanel();

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _InspectorItem(
        title: 'Ver empleados',
        subtitle: 'Consulta de plantilla',
        icon: Icons.people,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const UsersPage(readOnly: true),
            ),
          );
        },
      ),
      _InspectorItem(
        title: 'Ver fichajes',
        subtitle: 'Consulta de registros de jornada',
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
      _InspectorItem(
        title: 'Ver incidencias',
        subtitle: 'Consulta de incidencias registradas',
        icon: Icons.report_problem,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminIncidentsPage(readOnly: true),
            ),
          );
        },
      ),
      _InspectorItem(
        title: 'Ver vacaciones',
        subtitle: 'Consulta de solicitudes y calendario',
        icon: Icons.beach_access,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminVacationsPage(readOnly: true),
            ),
          );
        },
      ),
      _InspectorItem(
        title: 'Ver justificantes',
        subtitle: 'Consulta de justificantes subidos',
        icon: Icons.description,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminJustificationsPage(readOnly: true),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inspección',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 24.0 : 16.0;
            final maxContentWidth = isWide ? 1100.0 : 620.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 32,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Panel de inspección',
                          style: TextStyle(
                            fontSize: isWide ? 28 : 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.4),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.visibility,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Acceso en modo consulta.',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inspección de Trabajo tiene acceso remoto y en tiempo real a los registros de jornada en modo solo lectura para la verificación y control del cumplimiento de la legislación laboral.',
                          style: TextStyle(
                            fontSize: isWide ? 15 : 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (isWide)
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
                              return _InspectorDashboardCard(
                                item: items[index],
                              );
                            },
                          )
                        else
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InspectorDashboardCard(item: item),
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

class _InspectorItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _InspectorItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _InspectorDashboardCard extends StatelessWidget {
  final _InspectorItem item;

  const _InspectorDashboardCard({
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
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  size: 26,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }
}