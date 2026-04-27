import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkerIncidentsPage extends StatelessWidget {
  const WorkerIncidentsPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Aprobada';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Pendiente';
    }
  }

  String _typeLabel(dynamic type) {
    final t = (type ?? '').toString();
    if (t == 'forgot_in') return 'Entrada';
    if (t == 'forgot_out') return 'Salida';
    return 'Incidencia';
  }

  DateTime? _tsToDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    return null;
  }

  int _createdAtSortValue(Map<String, dynamic> data) {
    final createdAt = _tsToDate(data['createdAt']);
    final proposed = _tsToDate(data['proposedTime']);
    final d = createdAt ?? proposed ?? DateTime.fromMillisecondsSinceEpoch(0);
    return d.millisecondsSinceEpoch;
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yy $hh:$mi';
  }

  Widget _statusChip(String status) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // ✅ SIN orderBy -> NO requiere índice compuesto
    final stream = FirebaseFirestore.instance
        .collection('incidents')
        .where('uid', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis incidencias')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error cargando incidencias:\n${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No has enviado incidencias'));
            }

            final items = docs.map((d) => d.data()).toList()
              ..sort((a, b) =>
                  _createdAtSortValue(b).compareTo(_createdAtSortValue(a)));

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final data = items[i];
                final status = (data['status'] ?? 'pending').toString();
                final dt = _tsToDate(data['proposedTime']);
                final typeLabel = _typeLabel(data['type']);
                final reason = (data['reason'] ?? '').toString();
                final adminComment =
                    (data['adminComment'] ?? '').toString().trim();

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ Estado pegado a la derecha (siempre)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                typeLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _statusChip(status),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Text(
                          'Fecha/hora: ${_fmt(dt)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        Text(
                          'Motivo: $reason',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (status == 'rejected' && adminComment.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            "Comentario del administrador: $adminComment",
                            style: const TextStyle(
                              color: Colors.red,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}