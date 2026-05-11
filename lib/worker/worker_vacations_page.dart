import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/holidays_repository.dart';
import '../data/models/repositories/vacation_request.dart';
import '../data/models/repositories/vacations_repository.dart';
import '../utils/app_snackbar.dart';

class WorkerVacationsPage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const WorkerVacationsPage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<WorkerVacationsPage> createState() => _WorkerVacationsPageState();
}

class _WorkerVacationsPageState extends State<WorkerVacationsPage> {
  static const int defaultVacationDays = 22;

  final repo = VacationsRepository();
  final holidaysRepo = HolidaysRepository();
  final df = DateFormat('dd/MM/yyyy');

  String filter = 'all';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dateKey(DateTime d) {
    final x = _dateOnly(d);
    return '${x.year.toString().padLeft(4, '0')}-'
        '${x.month.toString().padLeft(2, '0')}-'
        '${x.day.toString().padLeft(2, '0')}';
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday ||
        day.weekday == DateTime.sunday;
  }

  bool _isHoliday(DateTime day, Set<String> holidayKeys) {
    return holidayKeys.contains(_dateKey(day));
  }

  int _workingDaysBetweenInclusive(
    DateTime start,
    DateTime end,
    Set<String> holidayKeys,
  ) {
    final startOnly = _dateOnly(start);
    final endOnly = _dateOnly(end);

    if (endOnly.isBefore(startOnly)) return 0;

    int count = 0;
    DateTime current = startOnly;

    while (!current.isAfter(endOnly)) {
      final isWeekend = _isWeekend(current);
      final isHoliday = _isHoliday(current, holidayKeys);

      if (!isWeekend && !isHoliday) {
        count++;
      }

      current = current.add(const Duration(days: 1));
    }

    return count;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancel_requested':
        return Colors.deepOrange;
      case 'cancelled':
        return Colors.grey;
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
      case 'cancel_requested':
        return 'Cancelación solicitada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return 'Pendiente';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'cancel_requested':
        return Icons.undo_rounded;
      case 'cancelled':
        return Icons.remove_circle_outline;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Future<void> _cancelPendingRequestDialog(VacationRequest request) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar solicitud'),
          content: Text(
            '¿Quieres cancelar esta solicitud de vacaciones?\n\n'
            '${df.format(request.startDate)} - ${df.format(request.endDate)}\n'
            'Días: ${request.days}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await repo.cancelPendingRequest(request.id);

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Solicitud cancelada correctamente',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error cancelando la solicitud: $e',
        isError: true,
      );
    }
  }

  Future<void> _requestCancellationDialog(VacationRequest request) async {
    final commentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final isSmall = mq.size.width < 380;

        return AlertDialog(
          title: const Text('Solicitar cancelación'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mq.size.width * 0.9),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vas a solicitar la cancelación de estas vacaciones:',
                    style: TextStyle(fontSize: isSmall ? 13 : 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${df.format(request.startDate)} - ${df.format(request.endDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 14 : 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Días: ${request.days}',
                    style: TextStyle(fontSize: isSmall ? 13 : 14),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la cancelación (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar solicitud'),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      commentCtrl.dispose();
      return;
    }

    try {
      await repo.requestCancellation(
        request.id,
        cancelRequestComment: commentCtrl.text,
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Solicitud de cancelación enviada al administrador',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error solicitando cancelación: $e',
        isError: true,
      );
    } finally {
      commentCtrl.dispose();
    }
  }

  Future<DateTime?> _pickSingleDateWithCalendar({
    required String title,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required Set<String> holidayKeys,
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    DateTime focusedDay = initialDate;
    DateTime? selectedDay = initialDate;

    return showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TableCalendar(
                      locale: 'es_ES',
                      firstDay: firstDate,
                      lastDay: lastDate,
                      focusedDay: focusedDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      selectedDayPredicate: (day) =>
                          selectedDay != null && isSameDay(day, selectedDay),
                      rangeStartDay: rangeStart,
                      rangeEndDay: rangeEnd,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {
                        CalendarFormat.month: 'Mes',
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        rangeStartDecoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        rangeEndDecoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        withinRangeDecoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle: const TextStyle(
                          color: Colors.grey,
                        ),
                        holidayTextStyle: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                        holidayDecoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      holidayPredicate: (day) => _isHoliday(day, holidayKeys),
                      enabledDayPredicate: (day) {
                        final d = _dateOnly(day);
                        return !d.isBefore(_dateOnly(firstDate)) &&
                            !d.isAfter(_dateOnly(lastDate));
                      },
                      onDaySelected: (selected, focused) {
                        setLocalState(() {
                          selectedDay = _dateOnly(selected);
                          focusedDay = focused;
                        });
                      },
                      onPageChanged: (focused) {
                        focusedDay = focused;
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          final isHoliday = _isHoliday(day, holidayKeys);
                          final isWeekend = _isWeekend(day);

                          if (!isHoliday && !isWeekend) return null;

                          return Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isHoliday
                                  ? Colors.red.withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.10),
                              shape: BoxShape.circle,
                              border: isHoliday
                                  ? Border.all(
                                      color: Colors.red.withOpacity(0.5),
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  color: isHoliday ? Colors.red : Colors.grey,
                                  fontWeight: isHoliday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Festivo'),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.10),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Fin de semana'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selectedDay == null
                      ? null
                      : () => Navigator.pop(context, selectedDay),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openRequestDialog(
    int remainingDays,
    Set<String> holidayKeys,
  ) async {
    if (remainingDays <= 0) {
      AppSnackbar.show(
        context,
        'No te quedan días de vacaciones disponibles',
        isError: true,
      );
      return;
    }

    DateTime? startDate;
    DateTime? endDate;
    final commentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final isSmall = mq.size.width < 380;

        return StatefulBuilder(
          builder: (context, setLocalState) {
            int requestedDays = 0;
            if (startDate != null && endDate != null) {
              requestedDays = _workingDaysBetweenInclusive(
                startDate!,
                endDate!,
                holidayKeys,
              );
            }

            return AlertDialog(
              title: const Text('Solicitar vacaciones'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: mq.size.width * 0.9,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event),
                        title: const Text('Fecha de inicio'),
                        subtitle: Text(
                          startDate == null
                              ? 'Seleccionar'
                              : df.format(startDate!),
                          style: TextStyle(fontSize: isSmall ? 13 : 14),
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);

                          final picked = await _pickSingleDateWithCalendar(
                            title: 'Selecciona la fecha de inicio',
                            initialDate: startDate ?? today,
                            firstDate: today,
                            lastDate: DateTime(now.year + 5, 12, 31),
                            holidayKeys: holidayKeys,
                            rangeStart: startDate,
                            rangeEnd: endDate,
                          );

                          if (picked != null) {
                            setLocalState(() {
                              startDate = picked;
                              if (endDate != null &&
                                  endDate!.isBefore(startDate!)) {
                                endDate = startDate;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_busy),
                        title: const Text('Fecha de fin'),
                        subtitle: Text(
                          endDate == null ? 'Seleccionar' : df.format(endDate!),
                          style: TextStyle(fontSize: isSmall ? 13 : 14),
                        ),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          if (startDate == null) return;

                          final picked = await _pickSingleDateWithCalendar(
                            title: 'Selecciona la fecha de fin',
                            initialDate: endDate ?? startDate!,
                            firstDate: startDate!,
                            lastDate: DateTime(startDate!.year + 5, 12, 31),
                            holidayKeys: holidayKeys,
                            rangeStart: startDate,
                            rangeEnd: endDate,
                          );

                          if (picked != null) {
                            setLocalState(() {
                              endDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comentario opcional',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Días laborables solicitados: $requestedDays',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmall ? 13 : 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Te quedan: $remainingDays',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: isSmall ? 13 : 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No se cuentan sábados, domingos ni festivos.',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: isSmall ? 12 : 13,
                          ),
                        ),
                      ),
                      if (requestedDays > remainingDays &&
                          requestedDays > 0) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No puedes solicitar más días de los que te quedan.',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: isSmall ? 13 : 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      if (startDate == null || endDate == null) {
                        AppSnackbar.show(
                          context,
                          'Selecciona fecha de inicio y fin',
                          isError: true,
                        );
                        return;
                      }

                      final days = _workingDaysBetweenInclusive(
                        startDate!,
                        endDate!,
                        holidayKeys,
                      );

                      if (days <= 0) {
                        AppSnackbar.show(
                          context,
                          'El rango seleccionado no tiene días laborables',
                          isError: true,
                        );
                        return;
                      }

                      if (days > remainingDays) {
                        AppSnackbar.show(
                          context,
                          'Los días solicitados no son válidos',
                          isError: true,
                        );
                        return;
                      }

                      await repo.createRequest(
                        employeeId: widget.employeeId,
                        employeeName: widget.employeeName,
                        startDate: startDate!,
                        endDate: endDate!,
                        days: days,
                        workerComment: commentCtrl.text,
                      );

                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      AppSnackbar.show(
                        context,
                        'Error enviando solicitud: $e',
                        isError: true,
                      );
                    }
                  },
                  child: const Text('Enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    commentCtrl.dispose();

    if (ok == true && mounted) {
      AppSnackbar.show(
        context,
        'Solicitud enviada',
      );
    }
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), size: 16, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _statusLabel(status),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    Widget chip({
      required String value,
      required IconData icon,
      required String tooltip,
    }) {
      final selected = filter == value;

      return Tooltip(
        message: tooltip,
        child: ChoiceChip(
          label: Icon(icon, size: 18),
          selected: selected,
          onSelected: (_) => setState(() => filter = value),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Todas'),
          selected: filter == 'all',
          onSelected: (_) => setState(() => filter = 'all'),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        chip(
          value: 'pending',
          icon: Icons.hourglass_top_rounded,
          tooltip: 'Pendientes',
        ),
        chip(
          value: 'approved',
          icon: Icons.check_circle_outline,
          tooltip: 'Aprobadas',
        ),
        chip(
          value: 'rejected',
          icon: Icons.cancel_outlined,
          tooltip: 'Rechazadas',
        ),
        chip(
          value: 'cancel_requested',
          icon: Icons.undo_rounded,
          tooltip: 'Cancelación solicitada',
        ),
        chip(
          value: 'cancelled',
          icon: Icons.remove_circle_outline,
          tooltip: 'Canceladas',
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;

    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isSmall ? 12 : 14,
            horizontal: isSmall ? 8 : 10,
          ),
          child: Column(
            children: [
              Icon(icon, size: isSmall ? 20 : 24),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmall ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: isSmall ? 12 : 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(VacationRequest r) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;

    final adminComment = r.adminComment.trim();
    final workerComment = r.workerComment.trim();
    final cancelRequestComment = r.cancelRequestComment.trim();

    final showRejectedComment =
        r.status == 'rejected' && adminComment.isNotEmpty;

    final showCancellationRequested =
        r.status == 'cancel_requested' && cancelRequestComment.isNotEmpty;

    final showCancellationDeniedComment =
        r.status == 'approved' &&
        adminComment.isNotEmpty &&
        r.cancelResolvedAt != null;

    final today = _dateOnly(DateTime.now());
    final canCancelPending =
        r.status == 'pending' &&
        !_dateOnly(r.startDate).isBefore(today);

    final canRequestCancellation =
      r.status == 'approved' &&
      !_dateOnly(r.startDate).isBefore(today);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.beach_access_rounded, size: isSmall ? 20 : 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${df.format(r.startDate)} - ${df.format(r.endDate)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 14 : 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: _statusChip(r.status)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Duración: ${r.days} día(s) laborable(s)',
              style: TextStyle(fontSize: isSmall ? 13 : 14),
            ),
            if (workerComment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blueGrey.withOpacity(0.20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu comentario',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 13 : 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      workerComment,
                      style: TextStyle(fontSize: isSmall ? 13 : 14),
                    ),
                  ],
                ),
              ),
            ],
            if (showRejectedComment) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.comment_outlined,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Motivo del rechazo',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: isSmall ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminComment,
                      style: TextStyle(fontSize: isSmall ? 13 : 14),
                    ),
                  ],
                ),
              ),
            ],
            if (showCancellationRequested) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.deepOrange.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.undo_rounded,
                          color: Colors.deepOrange,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Has solicitado la cancelación',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                            fontSize: isSmall ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cancelRequestComment,
                      style: TextStyle(fontSize: isSmall ? 13 : 14),
                    ),
                  ],
                ),
              ),
            ],
            if (showCancellationDeniedComment) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withOpacity(0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cancelación denegada',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                            fontSize: isSmall ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminComment,
                      style: TextStyle(fontSize: isSmall ? 13 : 14),
                    ),
                  ],
                ),
              ),
            ],
            if (canCancelPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelPendingRequestDialog(r),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Cancelar solicitud'),
                ),
              ),
            ],
            if (canRequestCancellation) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _requestCancellationDialog(r),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Solicitar cancelación'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentYear = now.year;
    final nextYear = now.year + 1;

    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;

    return StreamBuilder<List<Holiday>>(
      stream: holidaysRepo.streamHolidaysForYear(currentYear),
      builder: (context, holidaysSnapCurrent) {
        if (holidaysSnapCurrent.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Error cargando festivos: ${holidaysSnapCurrent.error}',
              ),
            ),
          );
        }

        if (!holidaysSnapCurrent.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<List<Holiday>>(
          stream: holidaysRepo.streamHolidaysForYear(nextYear),
          builder: (context, holidaysSnapNext) {
            if (holidaysSnapNext.hasError) {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Error cargando festivos: ${holidaysSnapNext.error}',
                  ),
                ),
              );
            }

            if (!holidaysSnapNext.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final allHolidays = <Holiday>[
              ...holidaysSnapCurrent.data!,
              ...holidaysSnapNext.data!,
            ];

            final holidayKeys = allHolidays.map((h) => h.key).toSet();

            return StreamBuilder<List<VacationRequest>>(
              stream: repo.streamEmployeeRequests(widget.employeeId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error cargando solicitudes: ${snap.error}'),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final myRequests = snap.data!;

                final usedDays = myRequests
                    .where((r) =>
                        r.status == 'approved' ||
                        r.status == 'cancel_requested')
                    .fold<int>(0, (sum, r) => sum + r.days);

                final remainingDays = defaultVacationDays - usedDays;

                List<VacationRequest> filteredRequests = myRequests;

                if (filter != 'all') {
                  filteredRequests =
                      myRequests.where((r) => r.status == filter).toList();
                }

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Vacaciones'),
                  ),
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _summaryCard(
                                title: 'Totales',
                                value: '$defaultVacationDays',
                                icon: Icons.event_available,
                              ),
                              _summaryCard(
                                title: 'Usados',
                                value: '$usedDays',
                                icon: Icons.beach_access,
                              ),
                              _summaryCard(
                                title: 'Restantes',
                                value: '$remainingDays',
                                icon: Icons.hourglass_bottom,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _openRequestDialog(remainingDays, holidayKeys),
                              icon: const Icon(Icons.add),
                              label: Text(
                                isSmall ? 'Solicitar' : 'Solicitar vacaciones',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Mis solicitudes',
                              style: TextStyle(
                                fontSize: isSmall ? 17 : 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _filterChips(),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filteredRequests.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No tienes solicitudes de vacaciones.',
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredRequests.length,
                                    itemBuilder: (context, index) {
                                      return _buildRequestCard(
                                        filteredRequests[index],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}