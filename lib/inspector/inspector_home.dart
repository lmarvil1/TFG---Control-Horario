import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_incidents_page.dart';
import '../admin/admin_justifications_page.dart';
import '../admin/admin_vacations_page.dart';
import '../admin/employee_punches_page.dart';
import '../admin/users_page.dart';

/// Pantalla principal del rol de Inspección de Trabajo.
/// Ofrece acceso en modo consulta a la información relevante para
/// la verificación de registros laborales, sin permitir modificaciones.
class InspectorHome extends StatelessWidget {
  const InspectorHome({super.key});

  /// Cierra la sesión del usuario autenticado.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    /// Opciones disponibles en el panel de inspección.
    /// Cada elemento define el texto, icono y navegación correspondiente.
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
        title: const Text('Inspección de Trabajo'),
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
            // Adaptación del diseño según el ancho disponible.
            final isWide = constraints.maxWidth >= 900;
            final horizontalPadding = isWide ? 24.0 : 16.0;
            final maxContentWidth = isWide ? 1100.0 : 620.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: isWide
                        // Diseño para pantallas grandes.
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Panel de inspección',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Aviso visual de que el acceso es solo de consulta.
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

                              // Texto descriptivo del alcance funcional del rol.
                              const Text(
                                'Inspección de Trabajo tiene acceso remoto y en tiempo real a los registros de jornada en modo solo lectura para la verificación y control del cumplimiento de la legislación laboral.',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Panel de opciones en formato cuadrícula.
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
                              ),
                            ],
                          )

                        // Diseño para pantallas pequeñas.
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 4),
                              ...items.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
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

/// Clase auxiliar que representa una opción del panel de inspección.
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

/// Tarjeta visual utilizada para mostrar una opción del panel.
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
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Icono principal de la opción.
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 18),

              // Título y descripción de la opción.
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

              // Indicador visual de navegación.
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