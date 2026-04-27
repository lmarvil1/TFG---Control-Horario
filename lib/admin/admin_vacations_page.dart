import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/repositories/employees.dart';
import '../data/models/repositories/employees_repository.dart';
import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/holidays_repository.dart';
import '../data/models/repositories/vacation_request.dart';
import '../data/models/repositories/vacations_repository.dart';
import '../utils/app_snackbar.dart';

class AdminVacationsPage extends StatefulWidget {
  final bool readOnly;

  const AdminVacationsPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<AdminVacationsPage> createState() => _AdminVacationsPageState();
}

class _AdminVacationsPageState extends State<AdminVacationsPage>
    with SingleTickerProviderStateMixin {
  final repo = VacationsRepository();
  final employeesRepo = EmployeesRepository();
  final holidaysRepo = HolidaysRepository();
  final df = DateFormat('dd/MM/yyyy', 'es_ES');

  late TabController _tabController;
  final ScrollController _quadrantHorizontalController = ScrollController();
  final ScrollController _quadrantVerticalController = ScrollController();

  DateTime visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime selectedDay =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  String requestFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _quadrantHorizontalController.dispose();
    _quadrantVerticalController.dispose();
    _tabController.dispose();
    super.dispose();
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

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isWeekend(DateTime day) {
    return day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
  }

  bool _isHoliday(DateTime day, List<Holiday> holidays) {
    return holidays.any((h) => _sameDate(h.date, day));
  }

  String? _holidayName(DateTime day, List<Holiday> holidays) {
    for (final h in holidays) {
      if (_sameDate(h.date, day)) return h.name;
    }
    return null;
  }

  bool _requestCoversDay(VacationRequest r, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );
    final end = DateTime(r.endDate.year, r.endDate.month, r.endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  bool _isApprovedVacationDay(
    VacationRequest r,
    DateTime day,
    List<Holiday> holidays,
  ) {
    return r.status == 'approved' &&
        !_isWeekend(day) &&
        !_isHoliday(day, holidays) &&
        _requestCoversDay(r, day);
  }

  List<VacationRequest> _approvedRequestsForDay(
    DateTime day,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) {
    return all.where((r) => _isApprovedVacationDay(r, day, holidays)).toList();
  }

  bool _employeeHasVacationOnDay(
    String employeeId,
    DateTime day,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) {
    return all.any(
      (r) =>
          r.employeeId == employeeId &&
          _isApprovedVacationDay(r, day, holidays),
    );
  }

  List<DateTime> _daysInVisibleMonth() {
    final lastDay = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    return List.generate(
      lastDay,
      (index) => DateTime(visibleMonth.year, visibleMonth.month, index + 1),
    );
  }

  int _workingDaysInRangeWithinYear(
    DateTime start,
    DateTime end,
    int year,
    List<Holiday> holidays,
  ) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);

    final yearStart = DateTime(year, 1, 1);
    final yearEnd = DateTime(year, 12, 31);

    final effectiveStart = rangeStart.isBefore(yearStart)
        ? yearStart
        : rangeStart;
    final effectiveEnd = rangeEnd.isAfter(yearEnd) ? yearEnd : rangeEnd;

    if (effectiveEnd.isBefore(effectiveStart)) return 0;

    int count = 0;
    DateTime current = effectiveStart;

    while (!current.isAfter(effectiveEnd)) {
      if (!_isWeekend(current) && !_isHoliday(current, holidays)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }

    return count;
  }

  int _approvedAnnualDaysForEmployee(
    String employeeId,
    List<VacationRequest> all,
    int year,
    List<Holiday> holidays,
  ) {
    return all
        .where((r) => r.employeeId == employeeId && r.status == 'approved')
        .fold<int>(
          0,
          (sum, r) => sum +
              _workingDaysInRangeWithinYear(
                r.startDate,
                r.endDate,
                year,
                holidays,
              ),
        );
  }

  void _changeVisibleMonth(int delta) {
    setState(() {
      final newMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + delta,
        1,
      );
      final lastDayOfNewMonth =
          DateTime(newMonth.year, newMonth.month + 1, 0).day;
      final newSelectedDay = min(selectedDay.day, lastDayOfNewMonth);

      visibleMonth = newMonth;
      selectedDay = DateTime(newMonth.year, newMonth.month, newSelectedDay);
    });
  }

  Future<void> _approve(VacationRequest request) async {
    try {
      await repo.approveRequest(request.id);
      if (!mounted) return;
      AppSnackbar.show(context, 'Solicitud aprobada');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error al aprobar la solicitud: $e',
        isError: true,
      );
    }
  }

  Future<void> _rejectDialog(VacationRequest request) async {
    final parentContext = context;
    String adminComment = '';

    final ok = await showDialog<bool>(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        final mq = MediaQuery.of(dialogContext);
        final isSmall = mq.size.width < 380;

        return AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mq.size.width * 0.85),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${request.employeeName}\n${df.format(request.startDate)} - ${df.format(request.endDate)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isSmall ? 13 : 14),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: '',
                    maxLines: 3,
                    onChanged: (value) => adminComment = value,
                    decoration: const InputDecoration(
                      labelText: 'Motivo del rechazo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 100));

    try {
      await repo.rejectRequest(request.id, adminComment.trim());
      if (!mounted) return;

      AppSnackbar.show(parentContext, 'Solicitud rechazada');
    } catch (e) {
      if (!mounted) return;

      AppSnackbar.show(
        parentContext,
        'Error al rechazar la solicitud: $e',
        isError: true,
      );
    }
  }

  Future<void> _approveCancellationDialog(VacationRequest request) async {
    final commentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aceptar cancelación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Se cancelarán las vacaciones de ${request.employeeName}.',
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Aceptar'),
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
      await repo.approveCancellation(request.id);

      if (!mounted) return;
      AppSnackbar.show(context, 'Cancelación aprobada');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error al aprobar la cancelación: $e',
        isError: true,
      );
    } finally {
      commentCtrl.dispose();
    }
  }

  Future<void> _denyCancellationDialog(VacationRequest request) async {
    final commentCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Denegar cancelación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Las vacaciones seguirán aprobadas para ${request.employeeName}.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo opcional',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Denegar'),
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
      await repo.denyCancellation(request.id, commentCtrl.text);

      if (!mounted) return;
      AppSnackbar.show(context, 'Cancelación denegada');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error al denegar la cancelación: $e',
        isError: true,
      );
    } finally {
      commentCtrl.dispose();
    }
  }

  Future<void> _exportQuadrantPdf(
    List<Employee> employees,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) async {
    try {
      final pdfBytes = await _buildQuadrantPdf(
        employees: employees,
        all: all,
        holidays: holidays,
      );

      final fileName =
          'cuadrante_${visibleMonth.year}_${visibleMonth.month.toString().padLeft(2, '0')}.pdf';

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error al generar el PDF: $e',
        isError: true,
      );
    }
  }

  Future<Uint8List> _buildQuadrantPdf({
    required List<Employee> employees,
    required List<VacationRequest> all,
    required List<Holiday> holidays,
  }) async {
    final pdf = pw.Document();
    final days = _daysInVisibleMonth();

    final sortedEmployees = [...employees]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    const int employeesPerPage = 18;

    for (
      int start = 0;
      start < sortedEmployees.length;
      start += employeesPerPage
    ) {
      final pageEmployees = sortedEmployees
          .skip(start)
          .take(employeesPerPage)
          .toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Cuadrante - ${DateFormat('MMMM yyyy', 'es_ES').format(visibleMonth)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildPdfLegend(),
                pw.SizedBox(height: 10),
                _buildPdfTable(
                  employees: pageEmployees,
                  all: all,
                  holidays: holidays,
                  days: days,
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Página ${(start ~/ employeesPerPage) + 1} de ${((sortedEmployees.length - 1) ~/ employeesPerPage) + 1}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    if (sortedEmployees.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Center(
              child: pw.Text(
                'No hay empleados para mostrar.',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _buildPdfLegend() {
    pw.Widget item(PdfColor color, String label, {PdfColor? borderColor}) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              color: color,
              border: pw.Border.all(color: borderColor ?? PdfColors.grey700),
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      );
    }

    return pw.Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        item(
          PdfColor.fromHex('#D9F2E3'),
          'Vacaciones aprobadas',
          borderColor: PdfColor.fromHex('#7CC596'),
        ),
        item(
          PdfColor.fromHex('#F6F1E8'),
          'Fin de semana',
          borderColor: PdfColor.fromHex('#E8DCC6'),
        ),
        item(
          PdfColor.fromHex('#F8D7DA'),
          'Festivo',
          borderColor: PdfColor.fromHex('#D9534F'),
        ),
      ],
    );
  }

  pw.Widget _buildPdfTable({
    required List<Employee> employees,
    required List<VacationRequest> all,
    required List<Holiday> holidays,
    required List<DateTime> days,
  }) {
    const double employeeWidth = 120;
    const double dayWidth = 20;
    const double totalWidth = 38;
    const double rowHeight = 24;

    final rows = <pw.TableRow>[];

    rows.add(
      pw.TableRow(
        children: [
          _pdfHeaderCell(
            'Empleado',
            width: employeeWidth,
            height: 34,
            background: PdfColors.grey200,
            alignment: pw.Alignment.centerLeft,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          ),
          ...days.map(
            (day) => _pdfDayHeaderCell(
              day: day,
              holidays: holidays,
              width: dayWidth,
              height: 34,
            ),
          ),
          _pdfHeaderCell(
            'Tot',
            width: totalWidth,
            height: 34,
            background: PdfColors.grey200,
          ),
        ],
      ),
    );

    for (final employee in employees) {
      final annualTotal = _approvedAnnualDaysForEmployee(
        employee.id,
        all,
        visibleMonth.year,
        holidays,
      );

      rows.add(
        pw.TableRow(
          children: [
            _pdfEmployeeCell(
              text: employee.name,
              width: employeeWidth,
              height: rowHeight,
              active: employee.active,
            ),
            ...days.map(
              (day) => _pdfDayCell(
                hasVacation: _employeeHasVacationOnDay(
                  employee.id,
                  day,
                  all,
                  holidays,
                ),
                isWeekend: _isWeekend(day),
                isHoliday: _isHoliday(day, holidays),
                width: dayWidth,
                height: rowHeight,
              ),
            ),
            _pdfTotalCell(
              '$annualTotal',
              width: totalWidth,
              height: rowHeight,
            ),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  pw.Widget _pdfHeaderCell(
    String text, {
    required double width,
    required double height,
    required PdfColor background,
    pw.Alignment alignment = pw.Alignment.center,
    pw.EdgeInsets padding = pw.EdgeInsets.zero,
  }) {
    return pw.Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      color: background,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfDayHeaderCell({
    required DateTime day,
    required List<Holiday> holidays,
    required double width,
    required double height,
  }) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final weekend = _isWeekend(day);
    final holiday = _isHoliday(day, holidays);

    PdfColor bg = PdfColors.grey200;
    PdfColor textColor = PdfColors.black;

    if (holiday) {
      bg = PdfColor.fromHex('#F8D7DA');
      textColor = PdfColor.fromHex('#8B1E24');
    } else if (weekend) {
      bg = PdfColor.fromHex('#F6F1E8');
      textColor = PdfColor.fromHex('#7A5A2E');
    }

    return pw.Container(
      width: width,
      height: height,
      color: bg,
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            labels[day.weekday - 1],
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.SizedBox(height: 1),
          pw.Text(
            '${day.day}',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfEmployeeCell({
    required String text,
    required double width,
    required double height,
    required bool active,
  }) {
    return pw.Container(
      width: width,
      height: height,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6),
      alignment: pw.Alignment.centerLeft,
      color: active ? PdfColors.white : PdfColors.grey100,
      child: pw.Text(
        text,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: active ? PdfColors.black : PdfColors.grey600,
        ),
      ),
    );
  }

  pw.Widget _pdfDayCell({
    required bool hasVacation,
    required bool isWeekend,
    required bool isHoliday,
    required double width,
    required double height,
  }) {
    PdfColor bg = PdfColors.white;
    String text = '';
    PdfColor textColor = PdfColors.black;

    if (isHoliday) {
      bg = PdfColor.fromHex('#F8D7DA');
      text = 'F';
      textColor = PdfColor.fromHex('#8B1E24');
    } else if (hasVacation) {
      bg = PdfColor.fromHex('#D9F2E3');
      text = 'V';
      textColor = PdfColors.black;
    } else if (isWeekend) {
      bg = PdfColor.fromHex('#F6F1E8');
    }

    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      color: bg,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  pw.Widget _pdfTotalCell(
    String text, {
    required double width,
    required double height,
  }) {
    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      color: PdfColors.white,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
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
              style: TextStyle(color: c, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    Widget chip(String label, String value) {
      final selected = requestFilter == value;

      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => requestFilter = value),
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
        chip('Cancelación solicitada', 'cancel_requested'),
        chip('Canceladas', 'cancelled'),
      ],
    );
  }

  Widget _requestCard(VacationRequest r) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;
    final canReview = !widget.readOnly && r.status == 'pending';
    final canResolveCancellation =
        !widget.readOnly && r.status == 'cancel_requested';

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
                    r.employeeName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmall ? 15 : 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: _statusChip(r.status)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Periodo: ${df.format(r.startDate)} - ${df.format(r.endDate)}',
              style: TextStyle(fontSize: isSmall ? 13 : 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Duración: ${r.days} día(s)',
              style: TextStyle(fontSize: isSmall ? 13 : 14),
            ),
            if (r.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Solicitada: ${df.format(r.createdAt!)}',
                style: TextStyle(fontSize: isSmall ? 13 : 14),
              ),
            ],
            if (r.workerComment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Comentario trabajador: ${r.workerComment}',
                style: TextStyle(fontSize: isSmall ? 13 : 14),
              ),
            ],
            if (r.status == 'rejected' && r.adminComment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo rechazo: ${r.adminComment}',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmall ? 13 : 14,
                ),
              ),
            ],
            if (r.status == 'cancel_requested') ...[
              const SizedBox(height: 8),
              Text(
                'El trabajador ha solicitado cancelar estas vacaciones.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmall ? 13 : 14,
                ),
              ),
              if (r.cancelRequestComment.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Motivo trabajador: ${r.cancelRequestComment}',
                  style: TextStyle(fontSize: isSmall ? 13 : 14),
                ),
              ],
            ],
            if (r.status == 'approved' &&
                r.cancelResolvedAt != null &&
                r.adminComment.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Cancelación denegada: ${r.adminComment}',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: isSmall ? 13 : 14,
                ),
              ),
            ],
            if (canReview) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      onPressed: () => _rejectDialog(r),
                      label: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      onPressed: () => _approve(r),
                      label: const Text('Aprobar'),
                    ),
                  ),
                ],
              ),
            ],
            if (canResolveCancellation) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.close),
                      onPressed: () => _denyCancellationDialog(r),
                      label: const Text('Denegar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      onPressed: () => _approveCancellationDialog(r),
                      label: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsTab(List<VacationRequest> all) {
    List<VacationRequest> filtered = all;

    if (requestFilter != 'all') {
      filtered = all.where((r) => r.status == requestFilter).toList();
    }

    filtered.sort((a, b) {
      final ad = a.createdAt ?? DateTime(2000);
      final bd = b.createdAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Align(alignment: Alignment.centerLeft, child: _filterChips()),
          const SizedBox(height: 12),
          Expanded(
            child: _buildRequestList(
              filtered,
              emptyText: 'No hay solicitudes.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(
    List<VacationRequest> items, {
    required String emptyText,
  }) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText));
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _requestCard(items[index]),
    );
  }

  Widget _buildSelectedDayList(
    List<VacationRequest> all,
    List<Holiday> holidays, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    final approvedForSelectedDay =
        _approvedRequestsForDay(selectedDay, all, holidays);
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;
    final holidayName = _holidayName(selectedDay, holidays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vacaciones el ${df.format(selectedDay)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmall ? 14 : 16,
                ),
              ),
              if (holidayName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Festivo: $holidayName',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: approvedForSelectedDay.isEmpty
              ? const Center(
                  child: Text('No hay trabajadores de vacaciones ese día'),
                )
              : ListView.builder(
                  itemCount: approvedForSelectedDay.length,
                  itemBuilder: (context, index) {
                    final r = approvedForSelectedDay[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(
                          r.employeeName,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${df.format(r.startDate)} - ${df.format(r.endDate)}',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCalendarTab(List<VacationRequest> all, List<Holiday> holidays) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final isLandscape = media.orientation == Orientation.landscape;
        final isTabletOrDesktop = constraints.maxWidth >= 900;

        if (isLandscape || isTabletOrDesktop) {
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isTabletOrDesktop ? 760 : 620,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCalendarHeader(),
                          const SizedBox(height: 6),
                          _buildMonthGrid(
                            all,
                            holidays,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 4,
                child: _buildSelectedDayList(
                  all,
                  holidays,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCalendarHeader(),
                      const SizedBox(height: 6),
                      _buildMonthGrid(
                        all,
                        holidays,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _buildSelectedDayList(
                all,
                holidays,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarHeader() {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeVisibleMonth(-1),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat('MMMM yyyy', 'es_ES').format(visibleMonth),
                style: TextStyle(
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => _changeVisibleMonth(1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(
    List<VacationRequest> all,
    List<Holiday> holidays, {
    required bool compact,
  }) {
    const weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final firstDayOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final lastDayOfMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0);

    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday;

    final List<Widget> cells = [];

    for (final d in weekDays) {
      cells.add(
        Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
          child: Text(
            d,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: compact ? 10 : 13,
            ),
          ),
        ),
      );
    }

    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, day);
      final approvedCount = _approvedRequestsForDay(date, all, holidays).length;
      final isSelected = _sameDate(date, selectedDay);
      final isHoliday = _isHoliday(date, holidays);

      cells.add(
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth;

            final dayFontSize = compact
                ? (cellWidth < 34 ? 10.0 : 12.0)
                : (cellWidth < 36
                      ? 11.0
                      : cellWidth < 46
                          ? 12.0
                          : 14.0);

            final badgeFontSize = compact
                ? (cellWidth < 34 ? 8.0 : 9.0)
                : (cellWidth < 36 ? 9.0 : 11.0);

            final badgeHPadding = compact
                ? (cellWidth < 38 ? 3.0 : 4.0)
                : (cellWidth < 40 ? 4.0 : 6.0);

            final badgeVPadding = compact ? 1.0 : (cellWidth < 40 ? 1.0 : 2.0);

            Color? backgroundColor;
            if (approvedCount > 0) {
              backgroundColor = Colors.green.withOpacity(0.10);
            } else if (isHoliday) {
              backgroundColor = Colors.red.shade100;
            }

            return InkWell(
              onTap: () {
                setState(() {
                  selectedDay = date;
                });
              },
              child: AspectRatio(
                aspectRatio: compact ? 1.25 : 1,
                child: Tooltip(
                  message:
                      isHoliday ? (_holidayName(date, holidays) ?? 'Festivo') : '',
                  child: Container(
                    margin: EdgeInsets.all(compact ? 1.5 : 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : isHoliday
                                ? Colors.red.shade400
                                : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(compact ? 6 : 8),
                      color: backgroundColor,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 2 : (cellWidth < 40 ? 4 : 6),
                        horizontal: 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: dayFontSize,
                                  color: isHoliday
                                      ? Colors.red.shade900
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: compact ? 1 : (cellWidth < 40 ? 2 : 4),
                          ),
                          if (approvedCount > 0)
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: badgeHPadding,
                                  vertical: badgeVPadding,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '$approvedCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: badgeFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (isHoliday)
                            Flexible(
                              child: Text(
                                'F',
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: badgeFontSize + 1,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: compact ? 8 : (cellWidth < 40 ? 12 : 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 4.0 : 8.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 4,
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: compact ? 1.25 : 1.0,
            ),
            itemBuilder: (context, index) => cells[index],
          ),
        );
      },
    );
  }

  Widget _buildQuadrantHeader() {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 480;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeVisibleMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('MMMM yyyy', 'es_ES').format(visibleMonth),
                      style: TextStyle(
                        fontSize: isSmall ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _changeVisibleMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legendItem(
                color: Colors.green.withOpacity(0.18),
                label: 'Vacaciones aprobadas',
                borderColor: Colors.green.shade300,
              ),
              _legendItem(
                color: const Color(0xFFF6F1E8),
                label: 'Fin de semana',
                borderColor: const Color(0xFFE8DCC6),
              ),
              _legendItem(
                color: Colors.red.shade100,
                label: 'Festivo',
                borderColor: Colors.red.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required Color borderColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  Widget _buildQuadrantTab(
    List<Employee> employees,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) {
    final days = _daysInVisibleMonth();
    const double nameWidth = 190;
    const double dayWidth = 36;
    const double totalWidth = 82;
    const double rowHeight = 44;

    final sortedEmployees = [...employees]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      children: [
        _buildQuadrantHeader(),
        const Divider(height: 1),
        Expanded(
          child: sortedEmployees.isEmpty
              ? const Center(child: Text('No hay empleados para mostrar.'))
              : Scrollbar(
                  controller: _quadrantVerticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _quadrantVerticalController,
                    padding: const EdgeInsets.all(12),
                    child: Scrollbar(
                      controller: _quadrantHorizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) =>
                          notification.depth == 1,
                      child: SingleChildScrollView(
                        controller: _quadrantHorizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _buildQuadrantTopHeaderRow(
                                days: days,
                                holidays: holidays,
                                nameWidth: nameWidth,
                                dayWidth: dayWidth,
                                totalWidth: totalWidth,
                                rowHeight: 52,
                              ),
                              ...sortedEmployees.map(
                                (employee) => _buildQuadrantEmployeeRow(
                                  employee: employee,
                                  days: days,
                                  all: all,
                                  holidays: holidays,
                                  year: visibleMonth.year,
                                  nameWidth: nameWidth,
                                  dayWidth: dayWidth,
                                  totalWidth: totalWidth,
                                  rowHeight: rowHeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQuadrantTopHeaderRow({
    required List<DateTime> days,
    required List<Holiday> holidays,
    required double nameWidth,
    required double dayWidth,
    required double totalWidth,
    required double rowHeight,
  }) {
    return Container(
      color: Colors.grey.shade100,
      child: Row(
        children: [
          _headerCell(
            text: 'Empleado',
            width: nameWidth,
            height: rowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          ...days.map(
            (day) => _buildDayHeaderCell(
              day: day,
              holidays: holidays,
              width: dayWidth,
              height: rowHeight,
            ),
          ),
          _headerCell(text: 'Total', width: totalWidth, height: rowHeight),
        ],
      ),
    );
  }

  Widget _buildDayHeaderCell({
    required DateTime day,
    required List<Holiday> holidays,
    required double width,
    required double height,
  }) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final weekend = _isWeekend(day);
    final holiday = _isHoliday(day, holidays);

    Color bg = Colors.grey.shade100;
    Color textColor = Colors.black87;
    Color borderColor = Colors.grey.shade300;

    if (holiday) {
      bg = Colors.red.shade100;
      textColor = Colors.red.shade900;
      borderColor = Colors.red.shade400;
    } else if (weekend) {
      bg = const Color(0xFFF6F1E8);
      textColor = Colors.brown.shade600;
      borderColor = const Color(0xFFE8DCC6);
    }

    return Tooltip(
      message: holiday ? (_holidayName(day, holidays) ?? 'Festivo') : '',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            left: BorderSide(color: borderColor),
            top: BorderSide(color: borderColor),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              labels[day.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrantEmployeeRow({
    required Employee employee,
    required List<DateTime> days,
    required List<VacationRequest> all,
    required List<Holiday> holidays,
    required int year,
    required double nameWidth,
    required double dayWidth,
    required double totalWidth,
    required double rowHeight,
  }) {
    final annualTotal = _approvedAnnualDaysForEmployee(
      employee.id,
      all,
      year,
      holidays,
    );

    return Row(
      children: [
        Container(
          width: nameWidth,
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: employee.active ? Colors.white : Colors.grey.shade100,
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Text(
            employee.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: employee.active ? Colors.black87 : Colors.black45,
            ),
          ),
        ),
        ...days.map(
          (day) => _buildQuadrantDayCell(
            hasVacation: _employeeHasVacationOnDay(
              employee.id,
              day,
              all,
              holidays,
            ),
            isWeekend: _isWeekend(day),
            isHoliday: _isHoliday(day, holidays),
            holidayName: _holidayName(day, holidays),
            width: dayWidth,
            height: rowHeight,
          ),
        ),
        Container(
          width: totalWidth,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey.shade300),
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            '$annualTotal',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrantDayCell({
    required bool hasVacation,
    required bool isWeekend,
    required bool isHoliday,
    required String? holidayName,
    required double width,
    required double height,
  }) {
    late final Color backgroundColor;
    late final Color borderColor;
    Widget? child;

    if (isHoliday) {
      backgroundColor = Colors.red.shade100;
      borderColor = Colors.red.shade400;
      child = Text(
        'F',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.red.shade900,
          fontSize: 16,
        ),
      );
    } else if (hasVacation) {
      backgroundColor = Colors.green.withOpacity(0.18);
      borderColor = Colors.green.shade300;
      child = const Text(
        'V',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      );
    } else if (isWeekend) {
      backgroundColor = const Color(0xFFF6F1E8);
      borderColor = const Color(0xFFE8DCC6);
      child = null;
    } else {
      backgroundColor = Colors.white;
      borderColor = Colors.grey.shade300;
      child = null;
    }

    return Tooltip(
      message: isHoliday ? (holidayName ?? 'Festivo') : '',
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: BorderSide(color: borderColor),
            top: BorderSide(color: borderColor),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _headerCell({
    required String text,
    required double width,
    required double height,
    Alignment alignment = Alignment.center,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return Container(
      width: width,
      height: height,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 380;

    return StreamBuilder<List<VacationRequest>>(
      stream: repo.streamAllRequests(),
      builder: (context, vacationsSnap) {
        if (vacationsSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final allRequests = vacationsSnap.data ?? [];

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: employeesRepo.streamEmployees(),
          builder: (context, employeesSnap) {
            if (employeesSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final employees = (employeesSnap.data?.docs ?? [])
                .map(Employee.fromDoc)
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );

            return StreamBuilder<List<Holiday>>(
              stream: holidaysRepo.streamHolidaysForYear(visibleMonth.year),
              builder: (context, holidaysSnap) {
                if (holidaysSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Text('Error cargando festivos: ${holidaysSnap.error}'),
                    ),
                  );
                }

                if (holidaysSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final holidays = holidaysSnap.data ?? [];

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      widget.readOnly ? 'Vacaciones' : 'Gestión de vacaciones',
                      style: TextStyle(fontSize: isSmall ? 18 : 20),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Descargar PDF del cuadrante',
                        icon: const Icon(Icons.picture_as_pdf),
                        onPressed: () => _exportQuadrantPdf(
                          employees,
                          allRequests,
                          holidays,
                        ),
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      isScrollable: width < 500,
                      tabs: const [
                        Tab(child: FittedBox(child: Text('Solicitudes'))),
                        Tab(child: FittedBox(child: Text('Calendario'))),
                        Tab(child: FittedBox(child: Text('Cuadrante'))),
                      ],
                    ),
                  ),
                  body: SafeArea(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestsTab(allRequests),
                        _buildCalendarTab(allRequests, holidays),
                        _buildQuadrantTab(employees, allRequests, holidays),
                      ],
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