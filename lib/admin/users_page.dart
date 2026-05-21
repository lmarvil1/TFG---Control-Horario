import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/employees_repository.dart';

/// Pantalla para la gestión de empleados.

/// Permite visualizar, crear, editar y eliminar empleados.
/// También puede utilizarse en modo solo lectura para la vista de RLT o Inspección.
class UsersPage extends StatefulWidget {
  /// Indica si la pantalla se muestra únicamente para consulta.
  final bool readOnly;

  const UsersPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  /// Repositorio encargado de gestionar empleados en Firestore.
  final repo = EmployeesRepository();

  /// Abre el formulario de creación o edición de empleado.
  /// Si se reciben datos, se utilizarán para editar.
  /// Si no, se creará un nuevo empleado.
  Future<void> _openEmployeeForm({
    String? id,
    String? name,
    String? department,
    bool? active,
  }) async {
    await showDialog<void>(
      context: context,

      // Evita cerrar el diálogo pulsando fuera.
      barrierDismissible: false,

      builder: (dialogContext) => EmployeeFormDialog(
        repo: repo,
        id: id,
        name: name,
        department: department,
        active: active,
      ),
    );
  }

  /// Muestra un diálogo de confirmación antes de eliminar un empleado.
  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),

        content: const Text(
          '¿Seguro que quieres eliminarlo?',
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),

          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    // Elimina el empleado si el usuario confirma.
    if (ok == true) {
      await repo.deleteEmployee(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.readOnly
              ? 'Empleados'
              : 'Gestionar empleados',
        ),

        // Muestra botón atrás solo si existe navegación previa.
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),

      // Botón flotante para añadir empleados.
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _openEmployeeForm(),
              child: const Icon(Icons.add),
            ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Escucha en tiempo real la colección de empleados.
          stream: repo.streamEmployees(),

          builder: (context, snap) {
            // Indicador de carga.
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Mensaje de error.
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),

                  child: Text(
                    'Error: ${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Lista de documentos obtenidos.
            final docs = snap.data?.docs ?? [];

            // Mensaje si no existen empleados.
            if (docs.isEmpty) {
              return const Center(
                child: Text('No hay empleados todavía.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),

              itemCount: docs.length,

              separatorBuilder: (_, __) =>
                  const Divider(height: 1),

              itemBuilder: (context, i) {
                final d = docs[i];

                // Datos del documento actual.
                final data = d.data();

                final name = (data['name'] ?? '') as String;
                final dep = (data['department'] ?? '') as String;
                final active = (data['active'] ?? true) as bool;

                // Texto descriptivo mostrado debajo del nombre.
                final subtitle =
                    '${dep.isEmpty ? "Sin departamento" : dep}'
                    '${active ? "" : " · INACTIVO"}';

                return ListTile(
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Menú de opciones solo en modo edición.
                  trailing: widget.readOnly
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: 'Opciones',

                          onSelected: (v) {
                            // Editar empleado.
                            if (v == 'edit') {
                              _openEmployeeForm(
                                id: d.id,
                                name: name,
                                department: dep,
                                active: active,
                              );

                            // Eliminar empleado.
                            } else if (v == 'delete') {
                              _confirmDelete(d.id);
                            }
                          },

                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),

                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
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

/// Diálogo utilizado para crear o editar empleados.
class EmployeeFormDialog extends StatefulWidget {
  /// Repositorio de empleados.
  final EmployeesRepository repo;

  /// ID del empleado.
  /// Si es null, se creará uno nuevo.
  final String? id;

  /// Nombre del empleado.
  final String? name;

  /// Departamento del empleado.
  final String? department;

  /// Estado activo/inactivo del empleado.
  final bool? active;

  const EmployeeFormDialog({
    super.key,
    required this.repo,
    this.id,
    this.name,
    this.department,
    this.active,
  });

  @override
  State<EmployeeFormDialog> createState() =>
      _EmployeeFormDialogState();
}

class _EmployeeFormDialogState
    extends State<EmployeeFormDialog> {

  /// Controlador del campo nombre.
  late final TextEditingController nameCtrl;

  /// Controlador del campo departamento.
  late final TextEditingController depCtrl;

  /// Estado activo del empleado.
  late bool isActive;

  /// Indica si se está guardando información.
  bool saving = false;

  /// Mensaje de error mostrado en pantalla.
  String? error;

  /// Detecta si el formulario está en modo edición.
  bool get isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();

    // Inicializa los campos con valores existentes.
    nameCtrl = TextEditingController(
      text: widget.name ?? '',
    );

    depCtrl = TextEditingController(
      text: widget.department ?? '',
    );

    isActive = widget.active ?? true;
  }

  @override
  void dispose() {
    // Libera memoria de los controladores.
    nameCtrl.dispose();
    depCtrl.dispose();

    super.dispose();
  }

  /// Guarda la información del empleado.
  Future<void> _save() async {
    // Evita múltiples pulsaciones.
    if (saving) return;

    try {
      setState(() {
        saving = true;
        error = null;
      });

      // Valores introducidos por el usuario.
      final nameVal = nameCtrl.text.trim();
      final depVal = depCtrl.text.trim();

      // Validación obligatoria del nombre.
      if (nameVal.isEmpty) {
        throw Exception('El nombre es obligatorio');
      }

      // Actualiza empleado existente.
      if (isEdit) {
        await widget.repo.updateEmployee(
          widget.id!,
          name: nameVal,
          department: depVal,
          active: isActive,
        );

      // Crea nuevo empleado.
      } else {
        await widget.repo.addEmployee(
          name: nameVal,
          department: depVal,
        );
      }

      if (!mounted) return;

      // Cierra el diálogo tras guardar correctamente.
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;

      // Muestra el error en pantalla.
      setState(() {
        error = e.toString().replaceFirst(
          'Exception: ',
          '',
        );

        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Espacio inferior para evitar que el teclado tape campos.
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return AlertDialog(
      title: Text(
        isEdit
            ? 'Editar empleado'
            : 'Nuevo empleado',
      ),

      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),

        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // Campo nombre.
              TextField(
                controller: nameCtrl,
                enabled: !saving,
                textInputAction: TextInputAction.next,

                decoration: const InputDecoration(
                  labelText: 'Nombre',
                ),
              ),

              const SizedBox(height: 8),

              // Campo departamento.
              TextField(
                controller: depCtrl,
                enabled: !saving,

                textInputAction: isEdit
                    ? TextInputAction.next
                    : TextInputAction.done,

                onSubmitted: (_) => _save(),

                decoration: const InputDecoration(
                  labelText: 'Departamento',
                ),
              ),

              const SizedBox(height: 8),

              // Interruptor de activo/inactivo solo en edición.
              if (isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,

                  title: const Text('Activo'),

                  value: isActive,

                  onChanged: saving
                      ? null
                      : (v) {
                          setState(() {
                            isActive = v;
                          });
                        },
                ),

              // Mensaje de error.
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),

                  child: Text(
                    error!,

                    style: const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      actions: [
        // Botón cancelar.
        TextButton(
          onPressed: saving
              ? null
              : () => Navigator.of(context).pop(),

          child: const Text('Cancelar'),
        ),

        // Botón guardar.
        ElevatedButton(
          onPressed: saving ? null : _save,

          child: saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}