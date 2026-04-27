import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsRepository repo = NotificationsRepository();

  bool _selectionMode = false;
  final Set<String> _selectedIds = <String>{};
  bool _busyDeleting = false;

  void _enterSelectionMode(String id) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(id);
    });
  }

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

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<AppNotification> items) {
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(items.map((e) => e.id));
    });
  }

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
        title: _selectionMode
            ? Text('${_selectedIds.length} seleccionadas')
            : const Text('Notificaciones'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancelar selección',
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          if (!_selectionMode)
            TextButton(
              onPressed: () async {
                try {
                  await repo.markAllAsRead();
                } catch (_) {}
              },
              child: const Text('Marcar todas'),
            ),
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
                          ? const Icon(Icons.circle, size: 10, color: Colors.red)
                          : null),
                  onLongPress: () => _enterSelectionMode(n.id),
                  onTap: () async {
                    if (_selectionMode) {
                      _toggleSelection(n.id);
                      return;
                    }

                    if (!n.isRead) {
                      try {
                        await repo.markAsRead(n.id);
                      } catch (_) {}
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

      default:
        return Icons.notifications_outlined;
    }
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Fecha desconocida';

    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}