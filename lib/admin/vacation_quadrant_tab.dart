import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/repositories/employees.dart';
import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/vacation_request.dart';
import '../utils/app_snackbar.dart';
import 'vacation_utils.dart';

/// Pestaña del cuadrante de vacaciones.

/// Permite visualizar:
/// - Vacaciones aprobadas.
/// - Festivos.
/// - Total anual por empleado.
class VacationQuadrantTab extends StatefulWidget {
  /// Lista de empleados.
  final List<Employee> employees;

  /// Lista completa de solicitudes.
  final List<VacationRequest> allRequests;

  /// Lista de festivos.
  final List<Holiday> holidays;

  /// Mes visible actualmente.
  final DateTime visibleMonth;

  /// Callback para cambiar de mes.
  final void Function(int delta) onMonthChanged;

  const VacationQuadrantTab({
    super.key,
    required this.employees,
    required this.allRequests,
    required this.holidays,
    required this.visibleMonth,
    required this.onMonthChanged,
  });

  @override
  State<VacationQuadrantTab> createState() => _VacationQuadrantTabState();
}

class _VacationQuadrantTabState extends State<VacationQuadrantTab> {
  /// Controlador del scroll horizontal del cuadrante.
  final ScrollController _horizontalController = ScrollController();

  /// Controlador del scroll vertical del cuadrante.
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    // Libera los controladores al cerrar la pantalla.
    _horizontalController.dispose();
    _verticalController.dispose();

    super.dispose();
  }

  /// Exporta el cuadrante actual en formato PDF.
  Future<void> _exportQuadrantPdf() async {
    try {
      // Genera los bytes del PDF.
      final pdfBytes = await _buildQuadrantPdf();

      // Nombre del archivo exportado.
      final fileName =
          'cuadrante_${widget.visibleMonth.year}_${widget.visibleMonth.month.toString().padLeft(2, '0')}.pdf';

      // Comparte o descarga el PDF según la plataforma.
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

  /// Construye el documento PDF del cuadrante.
  Future<Uint8List> _buildQuadrantPdf() async {
    final pdf = pw.Document();

    // Obtiene todos los días del mes visible.
    final days = VacationUtils.daysInMonth(widget.visibleMonth);

    // Ordena los empleados alfabéticamente.
    final sortedEmployees = [...widget.employees]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

    // Número máximo de empleados por página.
    const int employeesPerPage = 18;

    // Genera una página por cada bloque de empleados.
    for (int start = 0;
        start < sortedEmployees.length;
        start += employeesPerPage) {
      final pageEmployees =
          sortedEmployees.skip(start).take(employeesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(18),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Cuadrante - ${DateFormat('MMMM yyyy', 'es_ES').format(widget.visibleMonth)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 8),

                // Leyenda del PDF.
                _buildPdfLegend(),

                pw.SizedBox(height: 10),

                // Tabla principal del PDF.
                _buildPdfTable(
                  employees: pageEmployees,
                  days: days,
                ),

                pw.Spacer(),

                // Número de página.
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

    // Página alternativa si no hay empleados.
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

  /// Construye la leyenda del PDF.
  pw.Widget _buildPdfLegend() {
    /// Elemento individual de la leyenda.
    pw.Widget item(
      PdfColor color,
      String label, {
      PdfColor? borderColor,
    }) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              color: color,
              border: pw.Border.all(
                color: borderColor ?? PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(width: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9),
          ),
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

  /// Construye la tabla del PDF.
  pw.Widget _buildPdfTable({
    required List<Employee> employees,
    required List<DateTime> days,
  }) {
    const double employeeWidth = 120;
    const double dayWidth = 20;
    const double totalWidth = 38;
    const double rowHeight = 24;

    final rows = <pw.TableRow>[];

    // Cabecera de la tabla.
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

    // Filas de empleados.
    for (final employee in employees) {
      final annualTotal = VacationUtils.approvedAnnualDaysForEmployee(
        employeeId: employee.id,
        all: widget.allRequests,
        year: widget.visibleMonth.year,
        holidays: widget.holidays,
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
                hasVacation: VacationUtils.employeeHasVacationOnDay(
                  employee.id,
                  day,
                  widget.allRequests,
                  widget.holidays,
                ),
                isWeekend: VacationUtils.isWeekend(day),
                isHoliday: VacationUtils.isHoliday(
                  day,
                  widget.holidays,
                ),
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
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.5,
      ),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
    );
  }

  /// Construye una celda de cabecera del PDF.
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

  /// Construye una celda de cabecera para cada día del PDF.
  pw.Widget _pdfDayHeaderCell({
    required DateTime day,
    required double width,
    required double height,
  }) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final weekend = VacationUtils.isWeekend(day);

    final holiday = VacationUtils.isHoliday(
      day,
      widget.holidays,
    );

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

  /// Construye una celda de empleado del PDF.
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

  /// Construye una celda de día del PDF.
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

  /// Construye la celda del total anual en el PDF.
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

  /// Construye la cabecera visual del cuadrante.
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
                onPressed: () => widget.onMonthChanged(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('MMMM yyyy', 'es_ES').format(
                        widget.visibleMonth,
                      ),
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
                onPressed: () => widget.onMonthChanged(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: 'Descargar PDF del cuadrante',
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _exportQuadrantPdf,
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
                color: Colors.green.withValues(alpha: 0.18),
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

  /// Elemento de leyenda visual.
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
            border: Border.all(
              color: borderColor,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  /// Construye la fila superior del cuadrante.
  Widget _buildQuadrantTopHeaderRow({
    required List<DateTime> days,
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
              width: dayWidth,
              height: rowHeight,
            ),
          ),
          _headerCell(
            text: 'Usados',
            width: totalWidth,
            height: rowHeight,
          ),
        ],
      ),
    );
  }

  /// Construye una celda de cabecera para un día.
  Widget _buildDayHeaderCell({
    required DateTime day,
    required double width,
    required double height,
  }) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final weekend = VacationUtils.isWeekend(day);

    final holiday = VacationUtils.isHoliday(
      day,
      widget.holidays,
    );

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
      message: holiday
          ? (VacationUtils.holidayName(
                day,
                widget.holidays,
              ) ??
              'Festivo')
          : '',
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

  /// Construye una fila del cuadrante para un empleado.
  Widget _buildQuadrantEmployeeRow({
    required Employee employee,
    required List<DateTime> days,
    required int year,
    required double nameWidth,
    required double dayWidth,
    required double totalWidth,
    required double rowHeight,
  }) {
    final annualTotal = VacationUtils.approvedAnnualDaysForEmployee(
      employeeId: employee.id,
      all: widget.allRequests,
      year: year,
      holidays: widget.holidays,
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
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
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
            hasVacation: VacationUtils.employeeHasVacationOnDay(
              employee.id,
              day,
              widget.allRequests,
              widget.holidays,
            ),
            isWeekend: VacationUtils.isWeekend(day),
            isHoliday: VacationUtils.isHoliday(
              day,
              widget.holidays,
            ),
            holidayName: VacationUtils.holidayName(
              day,
              widget.holidays,
            ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Construye una celda diaria del cuadrante.
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
      backgroundColor = Colors.green.withValues(alpha: 0.18);
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

  /// Celda reutilizable de cabecera.
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
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = VacationUtils.daysInMonth(widget.visibleMonth);

    const double nameWidth = 190;
    const double dayWidth = 36;
    const double totalWidth = 82;
    const double rowHeight = 44;

    final sortedEmployees = [...widget.employees]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

    return Column(
      children: [
        _buildQuadrantHeader(),
        const Divider(height: 1),
        Expanded(
          child: sortedEmployees.isEmpty
              ? const Center(
                  child: Text('No hay empleados para mostrar.'),
                )
              : Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _verticalController,
                    padding: const EdgeInsets.all(12),
                    child: Scrollbar(
                      controller: _horizontalController,
                      thumbVisibility: true,
                      notificationPredicate: (notification) {
                        return notification.depth == 1;
                      },
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              _buildQuadrantTopHeaderRow(
                                days: days,
                                nameWidth: nameWidth,
                                dayWidth: dayWidth,
                                totalWidth: totalWidth,
                                rowHeight: 52,
                              ),
                              ...sortedEmployees.map(
                                (employee) =>
                                    _buildQuadrantEmployeeRow(
                                  employee: employee,
                                  days: days,
                                  year: widget.visibleMonth.year,
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
}