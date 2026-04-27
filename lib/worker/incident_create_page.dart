import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/app_snackbar.dart';

class IncidentCreatePage extends StatefulWidget {
  final String employeeId;

  const IncidentCreatePage({
    super.key,
    required this.employeeId,
  });

  @override
  State<IncidentCreatePage> createState() => _IncidentCreatePageState();
}

class _IncidentCreatePageState extends State<IncidentCreatePage> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  String type = 'forgot_in';
  final reasonCtrl = TextEditingController();
  bool loading = false;

  String _two(int n) => n.toString().padLeft(2, '0');

  String _time24(TimeOfDay t) {
    return "${_two(t.hour)}:${_two(t.minute)}";
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<String> _loadEmployeeName(String employeeId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .get();

      final data = doc.data();
      final name = (data?['name'] ?? '').toString().trim();

      return name.isEmpty ? 'Empleado' : name;
    } catch (_) {
      return 'Empleado';
    }
  }

  Future<void> _submit() async {
    if (reasonCtrl.text.trim().isEmpty) {
      _snack('Introduce un motivo', isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final proposedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      final employeeName = await _loadEmployeeName(widget.employeeId);

      await FirebaseFirestore.instance.collection('incidents').add({
        'employeeId': widget.employeeId,
        'employeeName': employeeName,
        'uid': user.uid,
        'type': type,
        'status': 'pending',
        'date': Timestamp.fromDate(selectedDate),
        'proposedTime': Timestamp.fromDate(proposedDateTime),
        'reason': reasonCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _snack('Incidencia enviada correctamente');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Error enviando incidencia: $e', isError: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    AppSnackbar.show(
      context,
      msg,
      isError: isError,
    );
  }

  @override
  void dispose() {
    reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        "${_two(selectedDate.day)}/${_two(selectedDate.month)}/${selectedDate.year}";

    final timeLabel = _time24(selectedTime);

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva incidencia')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(
                labelText: 'Tipo de incidencia',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'forgot_in',
                  child: Text('Olvidé fichar entrada'),
                ),
                DropdownMenuItem(
                  value: 'forgot_out',
                  child: Text('Olvidé fichar salida'),
                ),
              ],
              onChanged: (v) => setState(() => type = v!),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loading ? null : _pickDate,
              child: Text("Fecha: $dateLabel"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: loading ? null : _pickTime,
              child: Text("Hora: $timeLabel"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Enviar incidencia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}