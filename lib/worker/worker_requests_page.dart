import 'package:flutter/material.dart';

import 'worker_incidents_page.dart';
import 'worker_vacations_page.dart';

class WorkerRequestsPage extends StatelessWidget {
  final String employeeId;
  final String employeeName;

  const WorkerRequestsPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Solicitudes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gestiona tus incidencias y vacaciones desde este apartado.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),

          _RequestCard(
            icon: Icons.warning_amber_rounded,
            title: 'Incidencias',
            subtitle: 'Consulta tus incidencias y crea nuevas desde el botón +.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerIncidentsPage(
                    employeeId: employeeId,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 14),

          _RequestCard(
            icon: Icons.beach_access,
            title: 'Vacaciones',
            subtitle: 'Solicita vacaciones y revisa su estado.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerVacationsPage(
                    employeeId: employeeId,
                    employeeName: employeeName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RequestCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}