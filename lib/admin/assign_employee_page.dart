import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AssignEmployeePage extends StatefulWidget {
  const AssignEmployeePage({super.key});

  @override
  State<AssignEmployeePage> createState() => _AssignEmployeePageState();
}

class _AssignEmployeePageState extends State<AssignEmployeePage> {
  String? selectedUserId;
  String? selectedEmployeeId;
  String? selectedRole;

  bool inspectionAccessEnabled = false;
  DateTime? inspectionAccessUntil;

  String? msg;
  String? error;
  bool saving = false;

  static const List<String> _roles = [
    'worker',
    'admin',
    'rlt',
    'inspector',
  ];

  Future<void> assign() async {
    if (selectedUserId == null) {
      setState(() => error = 'Selecciona un usuario');
      return;
    }

    if (selectedRole == null || !_roles.contains(selectedRole)) {
      setState(() => error = 'Selecciona un rol válido');
      return;
    }

    if ((selectedRole == 'worker' || selectedRole == 'admin') &&
        (selectedEmployeeId == null || selectedEmployeeId!.trim().isEmpty)) {
      setState(() => error = 'Selecciona un empleado');
      return;
    }

    if (selectedRole == 'inspector' &&
        inspectionAccessEnabled &&
        inspectionAccessUntil == null) {
      setState(() => error = 'Selecciona una fecha de fin para el acceso');
      return;
    }

    setState(() {
      saving = true;
      error = null;
      msg = null;
    });

    try {
      final users = FirebaseFirestore.instance.collection('users');
      final userRef = users.doc(selectedUserId!);

      String employeeId = '';
      String name = '';
      String department = '';
      bool active = true;

      if (selectedRole == 'worker' || selectedRole == 'admin') {
        final employeeRef = FirebaseFirestore.instance
            .collection('employees')
            .doc(selectedEmployeeId!);

        final employeeSnap = await employeeRef.get();
        final employeeData = employeeSnap.data();

        if (!employeeSnap.exists || employeeData == null) {
          throw Exception('El empleado seleccionado no existe');
        }

        employeeId = selectedEmployeeId!.trim();
        name = (employeeData['name'] as String?)?.trim() ?? '';
        department = (employeeData['department'] as String?)?.trim() ?? '';
        active = employeeData['active'] as bool? ?? true;
      }

      final Map<String, dynamic> updateData = {
        'role': selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (selectedRole == 'worker' || selectedRole == 'admin') {
        updateData.addAll({
          'employeeId': employeeId,
          'name': name,
          'department': department,
          'active': active,
          'inspectionAccessEnabled': false,
          'inspectionAccessUntil': null,
        });
      } else if (selectedRole == 'rlt') {
        updateData.addAll({
          'employeeId': '',
          'name': '',
          'department': '',
          'active': true,
          'inspectionAccessEnabled': false,
          'inspectionAccessUntil': null,
        });
      } else if (selectedRole == 'inspector') {
        updateData.addAll({
          'employeeId': '',
          'name': '',
          'department': '',
          'active': true,
          'inspectionAccessEnabled': inspectionAccessEnabled,
          'inspectionAccessUntil': inspectionAccessEnabled
              ? Timestamp.fromDate(inspectionAccessUntil!)
              : null,
        });
      }

      await userRef.set(updateData, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => msg = '✅ Usuario actualizado correctamente');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Error: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _loadSelectedUserData(String userId) async {
    setState(() {
      msg = null;
      error = null;
      selectedEmployeeId = null;
      selectedRole = null;
      inspectionAccessEnabled = false;
      inspectionAccessUntil = null;
    });

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final data = snap.data();
      if (data == null) return;

      final role = (data['role'] as String?)?.trim();
      final employeeId = (data['employeeId'] as String?)?.trim();
      final enabled = data['inspectionAccessEnabled'] as bool? ?? false;
      final untilTs = data['inspectionAccessUntil'];

      setState(() {
        selectedRole = _roles.contains(role) ? role : 'worker';
        selectedEmployeeId =
            (employeeId != null && employeeId.isNotEmpty) ? employeeId : null;
        inspectionAccessEnabled = enabled;
        inspectionAccessUntil =
            untilTs is Timestamp ? untilTs.toDate() : null;
      });
    } catch (_) {
      // No bloqueamos la UI si falla la carga.
    }
  }

  Future<void> _pickInspectionUntil() async {
    final now = DateTime.now();
    final initialDate = inspectionAccessUntil ?? now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        inspectionAccessUntil ?? now.add(const Duration(hours: 1)),
      ),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      inspectionAccessUntil = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();

    final employeesStream = FirebaseFirestore.instance
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios y roles')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '1) Selecciona un usuario',
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: usersStream,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const LinearProgressIndicator();
                            }
                            if (snap.hasError) {
                              return Text('Error users: ${snap.error}');
                            }

                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Text('No hay usuarios todavía.');
                            }

                            return DropdownButtonFormField<String>(
                              value: selectedUserId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Usuario',
                                border: OutlineInputBorder(),
                              ),
                              items: docs.map((d) {
                                final data = d.data();
                                final email = (data['email'] ?? d.id) as String;
                                final userName =
                                    (data['name'] as String?)?.trim() ?? '';
                                final role =
                                    (data['role'] as String?)?.trim() ?? 'worker';
                                final empId =
                                    (data['employeeId'] as String?)?.trim();
                                final subtitle =
                                    (empId == null || empId.isEmpty)
                                        ? '$role · sin empleado'
                                        : '$role · empleado asignado';

                                final label = userName.isNotEmpty
                                    ? '$userName - $email ($subtitle)'
                                    : '$email ($subtitle)';

                                return DropdownMenuItem<String>(
                                  value: d.id,
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: saving
                                  ? null
                                  : (v) async {
                                      setState(() {
                                        selectedUserId = v;
                                        msg = null;
                                        error = null;
                                      });

                                      if (v != null) {
                                        await _loadSelectedUserData(v);
                                      }
                                    },
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '2) Selecciona el rol',
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Rol',
                            border: OutlineInputBorder(),
                          ),
                          items: _roles
                              .map(
                                (role) => DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role),
                                ),
                              )
                              .toList(),
                          onChanged: saving
                              ? null
                              : (v) {
                                  setState(() {
                                    selectedRole = v;
                                    msg = null;
                                    error = null;

                                    if (v == 'rlt' || v == 'inspector') {
                                      selectedEmployeeId = null;
                                    }

                                    if (v != 'inspector') {
                                      inspectionAccessEnabled = false;
                                      inspectionAccessUntil = null;
                                    }
                                  });
                                },
                        ),
                        if (selectedRole == 'worker' ||
                            selectedRole == 'admin') ...[
                          const SizedBox(height: 20),
                          const Text(
                            '3) Selecciona un empleado',
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 8),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: employeesStream,
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const LinearProgressIndicator();
                              }
                              if (snap.hasError) {
                                return Text('Error employees: ${snap.error}');
                              }

                              final docs = snap.data?.docs ?? [];
                              if (docs.isEmpty) {
                                return const Text('No hay empleados creados.');
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedEmployeeId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Empleado',
                                  border: OutlineInputBorder(),
                                ),
                                items: docs.map((d) {
                                  final data = d.data();
                                  final name = (data['name'] ?? '') as String;
                                  final dep =
                                      (data['department'] ?? '') as String;

                                  final label = dep.isEmpty ? name : '$name - $dep';

                                  return DropdownMenuItem<String>(
                                    value: d.id,
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: saving
                                    ? null
                                    : (v) {
                                        setState(() {
                                          selectedEmployeeId = v;
                                          msg = null;
                                          error = null;
                                        });
                                      },
                              );
                            },
                          ),
                        ],
                        if (selectedRole == 'inspector') ...[
                          const SizedBox(height: 20),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Activar acceso temporal'),
                            subtitle: const Text(
                              'El inspector solo podrá consultar si este acceso está activo.',
                            ),
                            value: inspectionAccessEnabled,
                            onChanged: saving
                                ? null
                                : (v) {
                                    setState(() {
                                      inspectionAccessEnabled = v;
                                      if (!v) {
                                        inspectionAccessUntil = null;
                                      }
                                    });
                                  },
                          ),
                          if (inspectionAccessEnabled) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: saving ? null : _pickInspectionUntil,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                inspectionAccessUntil == null
                                    ? 'Seleccionar fin de acceso'
                                    : 'Fin de acceso: ${_formatDateTime(inspectionAccessUntil!)}',
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            onPressed: saving ? null : assign,
                            child: saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Guardar cambios'),
                          ),
                        ),
                        if (msg != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            msg!,
                            style: const TextStyle(color: Colors.green),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 8),
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