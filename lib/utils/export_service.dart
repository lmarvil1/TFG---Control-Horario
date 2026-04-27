import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'punch_type_formatter.dart';
import 'work_time.dart';

class ExportService {
  static final DateFormat _dfDate = DateFormat('dd/MM/yyyy');
  static final DateFormat _dfTime = DateFormat('HH:mm');
  static final DateFormat _dfFileDay = DateFormat('yyyy-MM-dd');
  static final DateFormat _dfFileMonth = DateFormat('yyyy-MM');

  static String buildFilename({
    required String employeeLabel,
    required String ext,
    DateTime? now,
  }) {
    final d = now ?? DateTime.now();
    final safeName = _sanitizeFileName(employeeLabel);
    final datePart = _dfFileDay.format(d);
    return '${safeName}_$datePart.$ext';
  }

  static String buildFilenameForMonth({
    required String employeeLabel,
    required DateTime month,
    required String ext,
  }) {
    final safeName = _sanitizeFileName(employeeLabel);
    final monthPart = _dfFileMonth.format(DateTime(month.year, month.month, 1));
    return '${safeName}_$monthPart.$ext';
  }

  static String _sanitizeFileName(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'empleado' : cleaned;
  }

  /// CSV SIN LAT/LNG
  static Uint8List buildCsvBytes(List<Map<String, dynamic>> punches) {
    final rows = <List<dynamic>>[
      ["Fecha", "Hora", "Tipo"],
    ];

    for (final p in punches) {
      final ts = p['at'];
      if (ts is! Timestamp) continue;

      final dt = ts.toDate();

      rows.add([
        _dfDate.format(dt),
        _dfTime.format(dt),
        PunchTypeFormatter.label((p['type'] ?? '').toString()),
      ]);
    }

    final csv = const ListToCsvConverter(
      fieldDelimiter: ';',
      textDelimiter: '"',
      eol: '\r\n',
    ).convert(rows);

    return Uint8List.fromList(utf8.encode(csv));
  }

  static Future<Uint8List> buildPdfBytes({
    required List<Map<String, dynamic>> punches,
    required String employeeLabel,
    DateTime? downloadNow,
    DateTime? monthLabel,
  }) async {
    final downloadDate = downloadNow ?? DateTime.now();
    final month = monthLabel == null
        ? null
        : DateTime(monthLabel.year, monthLabel.month, 1);

    final perDay = WorkTime.minutesByDay(punches);
    final totalMin = WorkTime.totalMinutes(perDay);
    final ordinaryMin = WorkTime.totalOrdinaryMinutes(perDay);
    final extraMin = WorkTime.totalExtraMinutes(perDay);

    final sortedDays = perDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final doc = pw.Document();

    final tableData = punches.map((p) {
      final ts = p['at'];
      if (ts is! Timestamp) return ['', '', ''];

      final dt = ts.toDate();

      return [
        _dfDate.format(dt),
        _dfTime.format(dt),
        PunchTypeFormatter.label((p['type'] ?? '').toString()),
      ];
    }).toList();

    final dailySummaryData = sortedDays.map((entry) {
      final total = entry.value;
      final ordinary = WorkTime.ordinaryMinutes(total);
      final extra = WorkTime.extraMinutes(total);

      return [
        _dfDate.format(entry.key),
        WorkTime.formatHM(total),
        WorkTime.formatHM(ordinary),
        WorkTime.formatHM(extra),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            employeeLabel,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          if (month != null)
            pw.Text('Mes: ${DateFormat('MM/yyyy').format(month)}'),
          pw.Text(
            'Fecha de descarga: ${DateFormat('dd/MM/yyyy HH:mm').format(downloadDate)}',
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Resumen mensual',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Total horas mes: ${WorkTime.formatHM(totalMin)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text('Horas ordinarias: ${WorkTime.formatHM(ordinaryMin)}'),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Horas extra: ${WorkTime.formatHM(extraMin)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.orange700,
                  ),
                ),
              ],
            ),
          ),
          if (dailySummaryData.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Resumen diario',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Table.fromTextArray(
              headers: const ['Fecha', 'Total', 'Ordinarias', 'Extras'],
              data: dailySummaryData,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(1.3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
              },
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Detalle de fichajes',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: const ["Fecha", "Hora", "Tipo"],
            data: tableData,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(0.8),
            },
          ),
        ],
      ),
    );

    return doc.save();
  }
}