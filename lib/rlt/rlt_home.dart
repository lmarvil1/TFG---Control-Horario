import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../admin/admin_incidents_page.dart';
import '../admin/employee_punches_page.dart';
import '../admin/users_page.dart';

class RltHome extends StatelessWidget {
  const RltHome({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RltItem(
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
      _RltItem(
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
      _RltItem(
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Panel RLT',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
                          'Representación Legal de los Trabajadores (RLT)',
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
                          'La Representación Legal de los Trabajadores tiene acceso a los registros de jornada en modo consulta para supervisar el cumplimiento de la normativa laboral.',
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
                              return _RltDashboardCard(
                                item: items[index],
                              );
                            },
                          )
                        else
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RltDashboardCard(item: item),
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

class _RltItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RltItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _RltDashboardCard extends StatelessWidget {
  final _RltItem item;

  const _RltDashboardCard({
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