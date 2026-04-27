import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../utils/app_snackbar.dart';

class WorkerCreateIncidentPage extends StatefulWidget {
  final String employeeId;
  final bool showAppBar;

  const WorkerCreateIncidentPage({
    super.key,
    required this.employeeId,
    this.showAppBar = true,
  });

  @override
  State<WorkerCreateIncidentPage> createState() =>
      _WorkerCreateIncidentPageState();
}

class _WorkerCreateIncidentPageState extends State<WorkerCreateIncidentPage> {
  String type = 'forgot_in';
  DateTime proposed = DateTime.now();
  final reasonCtrl = TextEditingController();

  bool saving = false;

  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: proposed,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(proposed),
    );
    if (t == null) return;

    setState(() {
      proposed = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _typeLabel(String t) => t == 'forgot_in' ? 'Entrada' : 'Salida';

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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

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

  Future<void> _submit() async {
    if (saving) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final reason = reasonCtrl.text.trim();

    setState(() => saving = true);

    try {
      final docRef =
          await FirebaseFirestore.instance.collection('incidents').add({
        'uid': uid,
        'employeeId': widget.employeeId,
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
        debugPrint('Error enviando notificación de incidencia al admin: $e');
      }

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Incidencia enviada.',
      );

      if (widget.showAppBar) {
        Navigator.pop(context);
      } else {
        setState(() {
          type = 'forgot_in';
          proposed = DateTime.now();
          reasonCtrl.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error enviando incidencia: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _content() {
    final dt = proposed;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
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
            onChanged: (v) {
              if (v == null) return;
              setState(() => type = v);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : _pickDateTime,
              child: Text(
                "Fecha/hora: ${dt.day}/${dt.month}/${dt.year} "
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar incidencia'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Se enviará como: ${_typeLabel(type)}",
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAppBar) {
      return SingleChildScrollView(child: _content());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva incidencia')),
      body: SingleChildScrollView(child: _content()),
    );
  }
}