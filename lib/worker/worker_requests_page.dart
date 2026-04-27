import 'package:flutter/material.dart';

import 'justifications_page.dart';
import 'worker_create_incident_page.dart';
import 'worker_incidents_page.dart';

class WorkerRequestsPage extends StatelessWidget {
  final String employeeId;

  const WorkerRequestsPage({
    super.key,
    required this.employeeId,
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
            'Gestiona tus incidencias y justificantes desde este apartado.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _RequestCard(
            icon: Icons.warning_amber_rounded,
            title: 'Mis incidencias',
            subtitle: 'Consulta las incidencias enviadas y revisa su estado.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WorkerIncidentsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _RequestCard(
            icon: Icons.add_circle_outline,
            title: 'Nueva incidencia',
            subtitle: 'Crea una nueva solicitud por olvido de fichaje.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkerCreateIncidentPage(
                    employeeId: employeeId,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _RequestCard(
            icon: Icons.attach_file,
            title: 'Justificantes',
            subtitle: 'Sube documentos o imágenes justificativas.',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JustificationsPage(
                    employeeId: employeeId,
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
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
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