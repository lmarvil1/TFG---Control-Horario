import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../utils/app_snackbar.dart';

class AdminIncidentsPage extends StatefulWidget {
  final bool readOnly;

  const AdminIncidentsPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<AdminIncidentsPage> createState() => _AdminIncidentsPageState();
}

class _AdminIncidentsPageState extends State<AdminIncidentsPage> {
  String filter = 'all';

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('incidents');

  final Map<String, String> _employeeNameCache = {};
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

  String _typeLabel(String type) {
    switch (type) {
      case 'forgot_in':
        return 'Entrada olvidada';
      case 'forgot_out':
        return 'Salida olvidada';
      default:
        return type;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'forgot_in':
        return Icons.login;
      case 'forgot_out':
        return Icons.logout;
      default:
        return Icons.report_problem;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    Query<Map<String, dynamic>> q = _col;

    if (filter != 'all') {
      q = q.where('status', isEqualTo: filter);
    }

    q = q.orderBy('createdAt', descending: true);
    return q.snapshots();
  }

  Future<String?> _findUserUidByEmployeeId(String employeeId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('employeeId', isEqualTo: employeeId)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Future<void> _sendWorkerNotification({
    required String employeeId,
    required String incidentId,
    required String newStatus,
    required String type,
  }) async {
    final recipientUid = await _findUserUidByEmployeeId(employeeId);
    if (recipientUid == null || recipientUid.trim().isEmpty) return;

    final typeLabel = _typeLabel(type).toLowerCase();

    if (newStatus == 'approved') {
      await _notificationsRepo.createNotification(
        recipientUid: recipientUid,
        title: 'Incidencia aprobada',
        body: 'Tu incidencia de $typeLabel ha sido aprobada.',
        type: 'incident_resolved',
        relatedId: incidentId,
        relatedType: 'incident',
      );
      return;
    }

    if (newStatus == 'rejected') {
      await _notificationsRepo.createNotification(
        recipientUid: recipientUid,
        title: 'Incidencia rechazada',
        body: 'Tu incidencia de $typeLabel ha sido rechazada.',
        type: 'incident_rejected',
        relatedId: incidentId,
        relatedType: 'incident',
      );
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    String incidentId,
    String newStatus,
  ) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    try {
      String employeeIdForNotification = '';
      String incidentTypeForNotification = '';

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final incidentRef = _col.doc(incidentId);
        final snap = await tx.get(incidentRef);

        if (!snap.exists) {
          throw Exception('La incidencia no existe');
        }

        final data = snap.data()!;
        final currentStatus = (data['status'] ?? 'pending').toString();

        if (currentStatus != 'pending') {
          throw Exception('La incidencia ya fue revisada');
        }

        final employeeId = (data['employeeId'] ?? '').toString().trim();
        final type = (data['type'] ?? '').toString().trim();
        final proposedTime = data['proposedTime'];

        if (employeeId.isEmpty) {
          throw Exception('employeeId vacío en la incidencia');
        }

        employeeIdForNotification = employeeId;
        incidentTypeForNotification = type;

        if (newStatus == 'approved') {
          if (proposedTime is! Timestamp) {
            throw Exception('Tiempo de incidencia inválido');
          }

          String? punchType;
          if (type == 'forgot_in') {
            punchType = 'in';
          } else if (type == 'forgot_out') {
            punchType = 'out';
          }

          if (punchType == null) {
            throw Exception('Tipo de incidencia no válido');
          }

          final punchRef = FirebaseFirestore.instance
              .collection('punches')
              .doc(employeeId)
              .collection('items')
              .doc();

          tx.set(punchRef, {
            'type': punchType,
            'at': proposedTime,
            'source': 'incident',
            'incidentId': incidentId,
            'createdAt': FieldValue.serverTimestamp(),
            'locationOk': false,
          });
        }

        tx.update(incidentRef, {
          'status': newStatus,
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewedBy': adminUid,
        });
      });

      await _sendWorkerNotification(
        employeeId: employeeIdForNotification,
        incidentId: incidentId,
        newStatus: newStatus,
        type: incidentTypeForNotification,
      );

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Incidencia ${_statusLabel(newStatus).toLowerCase()}',
      );
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Error: $e',
        isError: true,
      );
    }
  }

  Widget _filterChips() {
    Widget chip(String label, String value) {
      final selected = filter == value;

      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => filter = value),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Todas', 'all'),
        chip('Pendientes', 'pending'),
        chip('Aprobadas', 'approved'),
        chip('Rechazadas', 'rejected'),
      ],
    );
  }

  String _safeStr(Map<String, dynamic> d, String key, {String fallback = '-'}) {
    final v = d[key];
    if (v == null) return fallback;
    if (v is String && v.trim().isEmpty) return fallback;
    return v.toString();
  }

  DateTime? _safeDate(Map<String, dynamic> d, String key) {
    final v = d[key];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '-';

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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _employeeNameWidget({
    required String employeeId,
  }) {
    final cached = _employeeNameCache[employeeId];

    if (cached != null) {
      return Text(
        cached,
        style: const TextStyle(fontWeight: FontWeight.w600),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .get(),
      builder: (context, snap) {
        final raw = snap.data?.data()?['name'];
        final name = (raw ?? 'Empleado').toString();

        _employeeNameCache[employeeId] = name;

        return Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Incidencias' : 'Incidencias'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _filterChips(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No hay incidencias.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final doc = docs[i];
                      final data = doc.data();

                      final status = (data['status'] ?? 'pending').toString();
                      final type = _safeStr(data, 'type');
                      final employeeId = _safeStr(data, 'employeeId');

                      final createdAt = _safeDate(data, 'createdAt');
                      final proposedTime = _safeDate(data, 'proposedTime');

                      final canReview = !widget.readOnly && status == 'pending';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(_typeIcon(type)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _typeLabel(type),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  _statusChip(status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _employeeNameWidget(employeeId: employeeId),
                              const SizedBox(height: 6),
                              Text('Creada: ${_fmtDate(createdAt)}'),
                              Text('Hora propuesta: ${_fmtDate(proposedTime)}'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (canReview) ...[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => _setStatus(
                                          context,
                                          doc.id,
                                          'rejected',
                                        ),
                                        label: const Text('Rechazar'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.check),
                                        onPressed: () => _setStatus(
                                          context,
                                          doc.id,
                                          'approved',
                                        ),
                                        label: const Text('Aprobar'),
                                      ),
                                    ),
                                  ] else
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: null,
                                        child: Text(
                                          'Estado: ${_statusLabel(status)}',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}