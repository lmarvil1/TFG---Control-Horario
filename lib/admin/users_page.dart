import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/employees_repository.dart';

class UsersPage extends StatefulWidget {
  final bool readOnly;

  const UsersPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final repo = EmployeesRepository();

  Future<void> _openEmployeeForm({
    String? id,
    String? name,
    String? department,
    bool? active,
  }) async {
    await showDialog<void>(
      context: context,
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

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: const Text('¿Seguro que quieres eliminarlo?'),
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

    if (ok == true) {
      await repo.deleteEmployee(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Empleados' : 'Gestionar empleados'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      floatingActionButton: widget.readOnly
      ? null
      : FloatingActionButton(
        onPressed: () => _openEmployeeForm(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: repo.streamEmployees(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

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

            final docs = snap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text('No hay empleados todavía.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final d = docs[i];
                final data = d.data();

                final name = (data['name'] ?? '') as String;
                final dep = (data['department'] ?? '') as String;
                final active = (data['active'] ?? true) as bool;

                final subtitle =
                    '${dep.isEmpty ? "Sin departamento" : dep}${active ? "" : " · INACTIVO"}';

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
                  trailing: widget.readOnly
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Opciones',
                        onSelected: (v) {
                          if (v == 'edit') {
                            _openEmployeeForm(
                              id: d.id,
                              name: name,
                              department: dep,
                              active: active,
                            );
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

class EmployeeFormDialog extends StatefulWidget {
  final EmployeesRepository repo;
  final String? id;
  final String? name;
  final String? department;
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
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController depCtrl;

  late bool isActive;
  bool saving = false;
  String? error;

  bool get isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.name ?? '');
    depCtrl = TextEditingController(text: widget.department ?? '');
    isActive = widget.active ?? true;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    depCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;

    try {
      setState(() {
        saving = true;
        error = null;
      });

      final nameVal = nameCtrl.text.trim();
      final depVal = depCtrl.text.trim();

      if (nameVal.isEmpty) {
        throw Exception('El nombre es obligatorio');
      }

      if (isEdit) {
        await widget.repo.updateEmployee(
          widget.id!,
          name: nameVal,
          department: depVal,
          active: isActive,
        );
      } else {
        await widget.repo.addEmployee(
          name: nameVal,
          department: depVal,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
        saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AlertDialog(
      title: Text(isEdit ? 'Editar empleado' : 'Nuevo empleado'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                enabled: !saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: depCtrl,
                enabled: !saving,
                textInputAction:
                    isEdit ? TextInputAction.next : TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  labelText: 'Departamento',
                ),
              ),
              const SizedBox(height: 8),
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
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}