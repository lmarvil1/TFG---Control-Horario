import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../utils/app_snackbar.dart';

class WorkerIncidentsPage extends StatelessWidget {
  final String employeeId;

  WorkerIncidentsPage({
    super.key,
    required this.employeeId,
  });

  final NotificationsRepository _notificationsRepo = NotificationsRepository();

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

  Future<List<String>> _getAdminUids() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    return snap.docs.map((d) => d.id).toList();
  }

  Future<String> _getCurrentUserDisplayName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      final data = userDoc.data();
      final name = (data?['name'] as String?)?.trim();

      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}

    return 'Un trabajador';
  }

  Future<void> _notifyAdmins({
    required String incidentId,
    required String workerName,
    required String incidentType,
  }) async {
    final adminUids = await _getAdminUids();

    if (adminUids.isEmpty) {
      debugPrint('No hay admins para notificar incidencia.');
      return;
    }

    final typeText =
        incidentType == 'forgot_in' ? 'entrada olvidada' : 'salida olvidada';

    for (final adminUid in adminUids) {
      await _notificationsRepo.createNotification(
        recipientUid: adminUid,
        title: 'Nueva incidencia',
        body: '$workerName ha enviado una incidencia de $typeText.',
        type: 'incident_created',
        relatedId: incidentId,
        relatedType: 'incident',
      );
    }
  }

  Future<void> _openCreateIncidentDialog(BuildContext context) async {
    String type = 'forgot_in';
    DateTime proposed = DateTime.now();
    bool saving = false;
    final reasonCtrl = TextEditingController();

    Future<void> pickDateTime(
      BuildContext dialogContext,
      void Function(void Function()) setLocalState,
    ) async {
      final d = await showDatePicker(
        context: dialogContext,
        locale: const Locale('es', 'ES'),
        initialDate: proposed,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime.now(),
      );

      if (d == null) return;

      final t = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.fromDateTime(proposed),
      );

      if (t == null) return;

      setLocalState(() {
        proposed = DateTime(d.year, d.month, d.day, t.hour, t.minute);
      });
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocalState) {
            Future<void> submit() async {
              if (saving) return;

              final uid = FirebaseAuth.instance.currentUser!.uid;
              final reason = reasonCtrl.text.trim();

              setLocalState(() => saving = true);

              try {
                final docRef = await FirebaseFirestore.instance
                    .collection('incidents')
                    .add({
                  'uid': uid,
                  'employeeId': employeeId,
                  'type': type,
                  'proposedTime': Timestamp.fromDate(proposed),
                  'reason': reason,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                try {
                  final workerName = await _getCurrentUserDisplayName();

                  await _notifyAdmins(
                    incidentId: docRef.id,
                    workerName: workerName,
                    incidentType: type,
                  );
                } catch (e) {
                  debugPrint(
                    'Error enviando notificación de incidencia al admin: $e',
                  );
                }

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);

                if (context.mounted) {
                  AppSnackbar.show(context, 'Incidencia enviada.');
                }
              } catch (e) {
                if (!dialogContext.mounted) return;

                setLocalState(() => saving = false);

                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    'Error enviando incidencia: $e',
                    isError: true,
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('Nueva incidencia'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'forgot_in',
                          child: Text('Olvidé fichar ENTRADA'),
                        ),
                        DropdownMenuItem(
                          value: 'forgot_out',
                          child: Text('Olvidé fichar SALIDA'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (v) {
                              if (v == null) return;
                              setLocalState(() => type = v);
                            },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () => pickDateTime(
                                  dialogContext,
                                  setLocalState,
                                ),
                        icon: const Icon(Icons.calendar_month),
                        label: Text('Fecha/hora: ${_fmt(proposed)}'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final stream = FirebaseFirestore.instance
        .collection('incidents')
        .where('uid', isEqualTo: uid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis incidencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva incidencia',
            onPressed: () => _openCreateIncidentDialog(context),
          ),
        ],
      ),
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
              return const Center(
                child: Text('No has enviado incidencias'),
              );
            }

            final items = docs.map((d) => d.data()).toList()
              ..sort(
                (a, b) =>
                    _createdAtSortValue(b).compareTo(_createdAtSortValue(a)),
              );

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
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (status == 'rejected' &&
                            adminComment.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Comentario del administrador: $adminComment',
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