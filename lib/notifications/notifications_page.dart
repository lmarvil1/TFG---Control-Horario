import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';

/// Pantalla de gestión de notificaciones del usuario.
/// Permite consultar notificaciones, marcarlas como leídas,
/// seleccionar varias y eliminarlas individualmente o en bloque.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  /// Repositorio encargado de acceder a las notificaciones.
  final NotificationsRepository repo = NotificationsRepository();

  /// Indica si la pantalla está en modo selección múltiple.
  bool _selectionMode = false;

  /// Conjunto de identificadores de notificaciones seleccionadas.
  final Set<String> _selectedIds = <String>{};

  /// Evita lanzar varias operaciones de borrado simultáneamente.
  bool _busyDeleting = false;

  /// Activa el modo selección y selecciona la notificación indicada.
  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

  /// Selecciona o deselecciona una notificación.
  /// Si no queda ninguna seleccionada, se desactiva el modo selección.
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  /// Limpia la selección actual.
  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// Selecciona todas las notificaciones mostradas.
  void _selectAll(List<AppNotification> items) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(items.map((e) => e.id));
    });
  }

  /// Elimina las notificaciones seleccionadas tras confirmación del usuario.
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _busyDeleting) return;

    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(count == 1
                ? 'Eliminar notificación'
                : 'Eliminar notificaciones'),
            content: Text(
              count == 1
                  ? '¿Seguro que quieres eliminar la notificación seleccionada?'
                  : '¿Seguro que quieres eliminar las $count notificaciones seleccionadas?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _busyDeleting = true);

    try {
      await repo.deleteNotifications(_selectedIds.toList());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Notificación eliminada'
                : '$count notificaciones eliminadas',
          ),
        ),
      );

      _clearSelection();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error eliminando notificaciones: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDeleting = false);
      }
    }
  }

  /// Elimina todas las notificaciones del usuario tras confirmación.
  Future<void> _deleteAll(List<AppNotification> items) async {
    if (items.isEmpty || _busyDeleting) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar todas las notificaciones'),
            content: Text(
              '¿Seguro que quieres eliminar las ${items.length} notificaciones?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar todas'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _busyDeleting = true);

    try {
      await repo.deleteAllMyNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las notificaciones han sido eliminadas'),
        ),
      );

      _clearSelection();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error eliminando todas las notificaciones: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Cambia el título cuando se activa la selección múltiple.
        title: _selectionMode
            ? Text('${_selectedIds.length} seleccionadas')
            : const Text('Notificaciones'),

        // En modo selección, permite cancelar la selección.
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar selección',
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          // Acción para marcar todas las notificaciones como leídas.
          if (!_selectionMode)
            TextButton(
              onPressed: () async {
                try {
                  await repo.markAllAsRead();
                } catch (_) {
                  // Si falla, no se bloquea la interfaz.
                }
              },
              child: const Text('Marcar todas'),
            ),

          // Menú de acciones generales.
          StreamBuilder<List<AppNotification>>(
            stream: repo.streamMyNotifications(),
            builder: (context, snap) {
              final items = snap.data ?? const <AppNotification>[];

              return PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'select_all') {
                    _selectAll(items);
                  } else if (value == 'delete_all') {
                    await _deleteAll(items);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'select_all',
                    child: Text('Seleccionar todas'),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Text('Borrar todas'),
                  ),
                ],
              );
            },
          ),

          // Eliminación de notificaciones seleccionadas.
          if (_selectionMode)
            IconButton(
              tooltip: 'Eliminar seleccionadas',
              onPressed: _selectedIds.isEmpty || _busyDeleting
                  ? null
                  : _deleteSelected,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          // Escucha en tiempo real las notificaciones del usuario.
          stream: repo.streamMyNotifications(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error cargando notificaciones: ${snap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final items = snap.data ?? [];

            // Limpia selecciones que ya no existan tras cambios en Firestore.
            if (_selectionMode) {
              final validIds = items.map((e) => e.id).toSet();
              _selectedIds.removeWhere((id) => !validIds.contains(id));

              if (_selectedIds.isEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectionMode) {
                    setState(() => _selectionMode = false);
                  }
                });
              }
            }

            if (items.isEmpty) {
              return const Center(
                child: Text('No tienes notificaciones.'),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                final selected = _selectedIds.contains(n.id);

                return ListTile(
                  selected: selected,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  leading: _selectionMode
                      ? Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleSelection(n.id),
                        )
                      : CircleAvatar(
                          backgroundColor: n.isRead
                              ? Colors.grey.withOpacity(0.15)
                              : Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.15),
                          child: Icon(
                            _iconForType(n.type),
                            color: n.isRead
                                ? Colors.grey
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight:
                          n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(n.body),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateTime(n.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  trailing: _selectionMode
                      ? null
                      : (!n.isRead
                          ? const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.red,
                            )
                          : null),
                  onLongPress: () => _enterSelectionMode(n.id),
                  onTap: () async {
                    if (_selectionMode) {
                      _toggleSelection(n.id);
                      return;
                    }

                    // Al abrir una notificación, se marca como leída.
                    if (!n.isRead) {
                      try {
                        await repo.markAsRead(n.id);
                      } catch (_) {
                        // No se interrumpe si falla la actualización.
                      }
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Devuelve el icono correspondiente según el tipo de notificación.
  static IconData _iconForType(String type) {
    switch (type) {
      case 'incident_created':
        return Icons.report_problem_outlined;
      case 'incident_resolved':
        return Icons.check_circle_outline;
      case 'incident_rejected':
        return Icons.cancel_outlined;
      case 'vacation_requested':
        return Icons.beach_access_outlined;
      case 'vacation_approved':
        return Icons.check_circle_outline;
      case 'vacation_rejected':
        return Icons.cancel_outlined;
      case 'vacation_cancel_requested':
        return Icons.undo_rounded;
      case 'vacation_cancel_approved':
        return Icons.event_busy_outlined;
      case 'vacation_cancel_denied':
        return Icons.block_outlined;
      case 'justification_uploaded':
      case 'justification_reviewed':
        return Icons.description_outlined;
      case 'inspection_access':
        return Icons.verified_user_outlined;
      case 'punch_reminder':
        return Icons.schedule_outlined;
      case 'payroll_uploaded':
        return Icons.receipt_long_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Formatea una fecha y hora en formato dd/mm/yyyy hh:mm.
  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Fecha desconocida';

    String two(int v) => v.toString().padLeft(2, '0');

    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}