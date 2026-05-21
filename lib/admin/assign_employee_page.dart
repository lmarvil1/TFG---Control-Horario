import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pantalla para asignar empleados y roles a los usuarios.

/// Permite configurar permisos y accesos especiales.
class AssignEmployeePage extends StatefulWidget {
  const AssignEmployeePage({super.key});

  @override
  State<AssignEmployeePage> createState() =>
      _AssignEmployeePageState();
}

class _AssignEmployeePageState
    extends State<AssignEmployeePage> {

  /// Usuario seleccionado actualmente.
  String? selectedUserId;

  /// Empleado asociado al usuario.
  String? selectedEmployeeId;

  /// Rol seleccionado.
  String? selectedRole;

  /// Indica si el acceso temporal del inspector está activo.
  bool inspectionAccessEnabled = false;

  /// Fecha límite del acceso temporal del inspector.
  DateTime? inspectionAccessUntil;

  /// Mensaje de éxito mostrado en pantalla.
  String? msg;

  /// Mensaje de error mostrado en pantalla.
  String? error;

  /// Indica si se está guardando información.
  bool saving = false;

  /// Lista de roles permitidos en la aplicación.
  static const List<String> _roles = [
    'worker',
    'admin',
    'rlt',
    'inspector',
  ];

  /// Guarda los cambios realizados en el usuario.
  Future<void> assign() async {

    // Validación de usuario seleccionado.
    if (selectedUserId == null) {
      setState(() => error = 'Selecciona un usuario');
      return;
    }

    // Validación del rol.
    if (selectedRole == null ||
        !_roles.contains(selectedRole)) {

      setState(() => error = 'Selecciona un rol válido');
      return;
    }

    // Validación del empleado asociado.
    if ((selectedRole == 'worker' ||
            selectedRole == 'admin') &&
        (selectedEmployeeId == null ||
            selectedEmployeeId!.trim().isEmpty)) {

      setState(() => error = 'Selecciona un empleado');
      return;
    }

    // Validación del acceso temporal del inspector.
    if (selectedRole == 'inspector' &&
        inspectionAccessEnabled &&
        inspectionAccessUntil == null) {

      setState(() => error =
          'Selecciona una fecha de fin para el acceso');

      return;
    }

    setState(() {
      saving = true;
      error = null;
      msg = null;
    });

    try {
      // Referencia a la colección de usuarios.
      final users =
          FirebaseFirestore.instance.collection('users');

      final userRef = users.doc(selectedUserId!);

      // Datos asociados al empleado.
      String employeeId = '';
      String name = '';
      String department = '';
      bool active = true;

      // Carga información del empleado
      // si el rol requiere empleado asociado.
      if (selectedRole == 'worker' ||
          selectedRole == 'admin') {

        final employeeRef = FirebaseFirestore.instance
            .collection('employees')
            .doc(selectedEmployeeId!);

        final employeeSnap = await employeeRef.get();
        final employeeData = employeeSnap.data();

        // Validación de existencia del empleado.
        if (!employeeSnap.exists ||
            employeeData == null) {

          throw Exception(
            'El empleado seleccionado no existe',
          );
        }

        employeeId = selectedEmployeeId!.trim();

        name =
            (employeeData['name'] as String?)
                    ?.trim() ??
                '';

        department =
            (employeeData['department'] as String?)
                    ?.trim() ??
                '';

        active =
            employeeData['active'] as bool? ?? true;
      }

      /// Datos que se actualizarán en Firestore.
      final Map<String, dynamic> updateData = {
        'role': selectedRole,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Configuración para trabajadores y administradores.
      if (selectedRole == 'worker' ||
          selectedRole == 'admin') {

        updateData.addAll({
          'employeeId': employeeId,
          'name': name,
          'department': department,
          'active': active,
          'inspectionAccessEnabled': false,
          'inspectionAccessUntil': null,
        });

      // Configuración para rol RLT.
      } else if (selectedRole == 'rlt') {

        updateData.addAll({
          'employeeId': '',
          'name': '',
          'department': '',
          'active': true,
          'inspectionAccessEnabled': false,
          'inspectionAccessUntil': null,
        });

      // Configuración para inspectores.
      } else if (selectedRole == 'inspector') {

        updateData.addAll({
          'employeeId': '',
          'name': '',
          'department': '',
          'active': true,

          'inspectionAccessEnabled':
              inspectionAccessEnabled,

          'inspectionAccessUntil':
              inspectionAccessEnabled
                  ? Timestamp.fromDate(
                      inspectionAccessUntil!,
                    )
                  : null,
        });
      }

      // Guarda los cambios en Firestore.
      await userRef.set(
        updateData,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        msg = 'Usuario actualizado correctamente';
      });

    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'Error: $e';
      });

    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  /// Carga la configuración actual del usuario seleccionado.
  Future<void> _loadSelectedUserData(
    String userId,
  ) async {

    // Reinicia estados anteriores.
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

      // Datos recuperados del usuario.
      final role =
          (data['role'] as String?)?.trim();

      final employeeId =
          (data['employeeId'] as String?)?.trim();

      final enabled =
          data['inspectionAccessEnabled']
                  as bool? ??
              false;

      final untilTs =
          data['inspectionAccessUntil'];

      setState(() {
        selectedRole =
            _roles.contains(role)
                ? role
                : 'worker';

        selectedEmployeeId =
            (employeeId != null &&
                    employeeId.isNotEmpty)
                ? employeeId
                : null;

        inspectionAccessEnabled = enabled;

        inspectionAccessUntil =
            untilTs is Timestamp
                ? untilTs.toDate()
                : null;
      });

    } catch (_) {
      // No bloqueamos la interfaz si falla la carga.
    }
  }

  /// Permite seleccionar la fecha y hora
  /// de finalización del acceso temporal.
  Future<void> _pickInspectionUntil() async {
    final now = DateTime.now();

    final initialDate =
        inspectionAccessUntil ??
            now.add(const Duration(days: 1));

    // Selector de fecha.
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );

    if (pickedDate == null || !mounted) return;

    // Selector de hora.
    final pickedTime = await showTimePicker(
      context: context,

      initialTime: TimeOfDay.fromDateTime(
        inspectionAccessUntil ??
            now.add(const Duration(hours: 1)),
      ),
    );

    if (pickedTime == null || !mounted) return;

    // Guarda la fecha y hora seleccionadas.
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

  /// Formatea la fecha y hora para mostrarla en pantalla.
  String _formatDateTime(DateTime dt) {
    String two(int v) =>
        v.toString().padLeft(2, '0');

    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {

    /// Stream en tiempo real de usuarios.
    final usersStream =
        FirebaseFirestore.instance
            .collection('users')
            .snapshots();

    /// Stream en tiempo real de empleados.
    final employeesStream = FirebaseFirestore
        .instance
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios y roles'),
      ),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),

              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),

                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 560,
                    ),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,

                      children: [

                        /// PASO 1
                        const Text(
                          '1) Selecciona un usuario',
                          textAlign: TextAlign.left,
                        ),

                        const SizedBox(height: 8),

                        StreamBuilder<
                            QuerySnapshot<
                                Map<String, dynamic>>>(
                          stream: usersStream,

                          builder: (context, snap) {

                            // Indicador de carga.
                            if (snap.connectionState ==
                                ConnectionState.waiting) {

                              return const LinearProgressIndicator();
                            }

                            // Error de carga.
                            if (snap.hasError) {
                              return Text(
                                'Error users: ${snap.error}',
                              );
                            }

                            final docs =
                                snap.data?.docs ?? [];

                            // Mensaje si no existen usuarios.
                            if (docs.isEmpty) {
                              return const Text(
                                'No hay usuarios todavía.',
                              );
                            }

                            return DropdownButtonFormField<String>(
                              initialValue: selectedUserId,
                              isExpanded: true,

                              decoration:
                                  const InputDecoration(
                                labelText: 'Usuario',
                                border:
                                    OutlineInputBorder(),
                              ),

                              items: docs.map((d) {
                                final data = d.data();

                                final email =
                                    (data['email'] ?? d.id)
                                        as String;

                                final userName =
                                    (data['name']
                                                as String?)
                                            ?.trim() ??
                                        '';

                                final role =
                                    (data['role']
                                                as String?)
                                            ?.trim() ??
                                        'worker';

                                final empId =
                                    (data['employeeId']
                                            as String?)
                                        ?.trim();

                                final subtitle =
                                    (empId == null ||
                                            empId
                                                .isEmpty)
                                        ? '$role · sin empleado'
                                        : '$role · empleado asignado';

                                final label =
                                    userName.isNotEmpty
                                        ? '$userName - $email ($subtitle)'
                                        : '$email ($subtitle)';

                                return DropdownMenuItem<
                                    String>(
                                  value: d.id,

                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                  ),
                                );
                              }).toList(),

                              onChanged: saving
                                  ? null
                                  : (v) async {

                                      setState(() {
                                        selectedUserId =
                                            v;

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

                        /// PASO 2
                        const Text(
                          '2) Selecciona el rol',
                          textAlign: TextAlign.left,
                        ),

                        const SizedBox(height: 8),

                        DropdownButtonFormField<String>(
                          initialValue: selectedRole,
                          isExpanded: true,

                          decoration:
                              const InputDecoration(
                            labelText: 'Rol',
                            border:
                                OutlineInputBorder(),
                          ),

                          items: _roles
                              .map(
                                (role) =>
                                    DropdownMenuItem<
                                        String>(
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

                                    // Roles sin empleado asociado.
                                    if (v == 'rlt' ||
                                        v ==
                                            'inspector') {

                                      selectedEmployeeId =
                                          null;
                                    }

                                    // Reinicia acceso temporal.
                                    if (v !=
                                        'inspector') {

                                      inspectionAccessEnabled =
                                          false;

                                      inspectionAccessUntil =
                                          null;
                                    }
                                  });
                                },
                        ),

                        /// PASO 3
                        if (selectedRole ==
                                'worker' ||
                            selectedRole ==
                                'admin') ...[

                          const SizedBox(height: 20),

                          const Text(
                            '3) Selecciona un empleado',
                            textAlign: TextAlign.left,
                          ),

                          const SizedBox(height: 8),

                          StreamBuilder<
                              QuerySnapshot<
                                  Map<String, dynamic>>>(
                            stream: employeesStream,

                            builder: (context, snap) {

                              if (snap.connectionState ==
                                  ConnectionState
                                      .waiting) {

                                return const LinearProgressIndicator();
                              }

                              if (snap.hasError) {
                                return Text(
                                  'Error employees: ${snap.error}',
                                );
                              }

                              final docs =
                                  snap.data?.docs ??
                                      [];

                              if (docs.isEmpty) {
                                return const Text(
                                  'No hay empleados creados.',
                                );
                              }

                              return DropdownButtonFormField<
                                  String>(
                                initialValue:
                                    selectedEmployeeId,

                                isExpanded: true,

                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Empleado',

                                  border:
                                      OutlineInputBorder(),
                                ),

                                items: docs.map((d) {
                                  final data =
                                      d.data();

                                  final name =
                                      (data['name'] ??
                                              '')
                                          as String;

                                  final dep =
                                      (data['department'] ??
                                              '')
                                          as String;

                                  final label =
                                      dep.isEmpty
                                          ? name
                                          : '$name - $dep';

                                  return DropdownMenuItem<
                                      String>(
                                    value: d.id,

                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                  );
                                }).toList(),

                                onChanged: saving
                                    ? null
                                    : (v) {

                                        setState(() {
                                          selectedEmployeeId =
                                              v;

                                          msg = null;
                                          error = null;
                                        });
                                      },
                              );
                            },
                          ),
                        ],

                        /// Configuración adicional del inspector.
                        if (selectedRole ==
                            'inspector') ...[

                          const SizedBox(height: 20),

                          SwitchListTile(
                            contentPadding:
                                EdgeInsets.zero,

                            title: const Text(
                              'Activar acceso temporal',
                            ),

                            subtitle: const Text(
                              'El inspector solo podrá consultar si este acceso está activo.',
                            ),

                            value:
                                inspectionAccessEnabled,

                            onChanged: saving
                                ? null
                                : (v) {

                                    setState(() {
                                      inspectionAccessEnabled =
                                          v;

                                      if (!v) {
                                        inspectionAccessUntil =
                                            null;
                                      }
                                    });
                                  },
                          ),

                          if (inspectionAccessEnabled) ...[
                            const SizedBox(height: 8),

                            OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : _pickInspectionUntil,

                              icon: const Icon(
                                Icons.calendar_today,
                              ),

                              label: Text(
                                inspectionAccessUntil ==
                                        null
                                    ? 'Seleccionar fin de acceso'
                                    : 'Fin de acceso: ${_formatDateTime(inspectionAccessUntil!)}',
                              ),
                            ),
                          ],
                        ],

                        const SizedBox(height: 20),

                        /// Botón guardar cambios.
                        SizedBox(
                          width: double.infinity,

                          child: ElevatedButton(
                            style:
                                ElevatedButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(
                                48,
                              ),
                            ),

                            onPressed:
                                saving
                                    ? null
                                    : assign,

                            child: saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,

                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Guardar cambios',
                                  ),
                          ),
                        ),

                        // Mensaje de éxito.
                        if (msg != null) ...[
                          const SizedBox(height: 12),

                          Text(
                            msg!,
                            style: const TextStyle(
                              color: Colors.green,
                            ),
                            textAlign:
                                TextAlign.center,
                          ),
                        ],

                        // Mensaje de error.
                        if (error != null) ...[
                          const SizedBox(height: 12),

                          Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.red,
                            ),
                            textAlign:
                                TextAlign.center,
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