import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_snackbar.dart';
import '../utils/export_service.dart';
import '../utils/file_downloader.dart';

class PunchesHistoryPage extends StatefulWidget {
  final String employeeId;

  const PunchesHistoryPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<PunchesHistoryPage> createState() => _PunchesHistoryPageState();
}

class _PunchesHistoryPageState extends State<PunchesHistoryPage> {
  final dfDay = DateFormat('dd/MM/yyyy');
  final dfTime = DateFormat('HH:mm');

  /// 0 = Día | 1 = Mes
  int mode = 0;

  DateTime selectedDay = DateTime.now();
  DateTime selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  String? employeeLabel;

  static const int ordinaryDailyMinutes = 480; // 8 horas

  @override
  void initState() {
    super.initState();
    _loadEmployeeLabel();
  }

  Future<void> _loadEmployeeLabel() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();

      final data = doc.data();
      final name = (data?['name'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        employeeLabel = name.isEmpty ? widget.employeeId : name;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        employeeLabel = widget.employeeId;
      });
    }
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedDay,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => selectedDay = DateTime(d.year, d.month, d.day));
    }
  }

  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => selectedMonth = DateTime(d.year, d.month, 1));
    }
  }

  DateTime _rangeStart() {
    if (mode == 0) {
      return DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    }
    return DateTime(selectedMonth.year, selectedMonth.month, 1);
  }

  DateTime _rangeEndExclusive() {
    if (mode == 0) return _rangeStart().add(const Duration(days: 1));

    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    return (start.month == 12)
        ? DateTime(start.year + 1, 1, 1)
        : DateTime(start.year, start.month + 1, 1);
  }

  int _workedMinutes(List<_Punch> punches) {
    int minutes = 0;
    DateTime? openIn;

    for (final p in punches) {
      if (p.type == 'in') {
        openIn = p.at;
      } else if (p.type == 'out') {
        if (openIn != null && p.at.isAfter(openIn)) {
          minutes += p.at.difference(openIn).inMinutes;
          openIn = null;
        }
      }
    }
    return minutes;
  }

  int _ordinaryMinutes(int workedMinutes) {
    if (workedMinutes <= 0) return 0;
    return workedMinutes > ordinaryDailyMinutes
        ? ordinaryDailyMinutes
        : workedMinutes;
  }

  int _extraMinutes(int workedMinutes) {
    if (workedMinutes <= ordinaryDailyMinutes) return 0;
    return workedMinutes - ordinaryDailyMinutes;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _sanitizeFilePart(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return cleaned.isEmpty ? 'trabajador' : cleaned;
  }

  String _buildPdfFilename() {
    final rawName = (employeeLabel ?? widget.employeeId).trim();
    final safeName = _sanitizeFilePart(rawName);
    final monthPart = DateFormat('yyyy_MM').format(selectedMonth);

    return '${safeName}_$monthPart.pdf';
  }

  Future<void> _downloadPdf(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (mode != 1 || docs.isEmpty) return;

    try {
      final punches = docs.map((d) => d.data()).toList();
      final label = (employeeLabel ?? widget.employeeId).trim();

      final Uint8List pdfBytes = await ExportService.buildPdfBytes(
        punches: punches,
        employeeLabel: label,
        downloadNow: DateTime.now(),
        monthLabel: selectedMonth,
      );

      final filename = _buildPdfFilename();

      await downloadBytes(
        bytes: pdfBytes,
        filename: filename,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'PDF descargado: $filename',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error exportando PDF: $e',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _rangeStart();
    final end = _rangeEndExclusive();

    final query = FirebaseFirestore.instance
        .collection('punches')
        .doc(widget.employeeId)
        .collection('items')
        .where('at', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('at', isLessThan: Timestamp.fromDate(end))
        .orderBy('at', descending: true);

    final title = mode == 0
        ? 'Día: ${dfDay.format(selectedDay)}'
        : 'Mes: ${DateFormat('MM/yyyy').format(selectedMonth)}';

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Historial de fichajes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Día'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Mes'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => setState(() => mode = s.first),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: mode == 0 ? _pickDay : _pickMonth,
                  icon: const Icon(Icons.filter_alt),
                  label: Text(title),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Error: ${snap.error}'),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No hay fichajes en este periodo.'),
                  );
                }

                final punchesDesc = docs.map((d) {
                  final data = d.data();
                  final ts = data['at'] as Timestamp?;

                  return _Punch(
                    id: d.id,
                    type: (data['type'] ?? '').toString(),
                    at: ts?.toDate() ?? DateTime.now(),
                    pendingSync: d.metadata.hasPendingWrites,
                    source: (data['source'] ?? 'mobile').toString(),
                  );
                }).toList();

                final punchesAsc = List<_Punch>.from(punchesDesc)
                  ..sort((a, b) => a.at.compareTo(b.at));

                final perDayMinutes = <DateTime, int>{};
                int totalMinutes;

                if (mode == 1) {
                  final grouped = <DateTime, List<_Punch>>{};

                  for (final p in punchesAsc) {
                    final dayKey = DateTime(p.at.year, p.at.month, p.at.day);
                    grouped.putIfAbsent(dayKey, () => []).add(p);
                  }

                  grouped.forEach((day, list) {
                    list.sort((a, b) => a.at.compareTo(b.at));
                    perDayMinutes[day] = _workedMinutes(list);
                  });

                  totalMinutes =
                      perDayMinutes.values.fold<int>(0, (a, b) => a + b);
                } else {
                  totalMinutes = _workedMinutes(punchesAsc);
                }

                final totalOrdinaryMinutes = mode == 0
                    ? _ordinaryMinutes(totalMinutes)
                    : perDayMinutes.values
                        .fold<int>(0, (sum, day) => sum + _ordinaryMinutes(day));

                final totalExtraMinutes = mode == 0
                    ? _extraMinutes(totalMinutes)
                    : perDayMinutes.values
                        .fold<int>(0, (sum, day) => sum + _extraMinutes(day));

                final sortedEntries = perDayMinutes.entries.toList()
                  ..sort((a, b) => b.key.compareTo(a.key));

                final canExport = mode == 1 && docs.isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total trabajado (${mode == 0 ? "día" : "mes"})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatMinutes(totalMinutes),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ordinarias: ${_formatMinutes(totalOrdinaryMinutes)}',
                            ),
                            if (totalExtraMinutes > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Extras: ${_formatMinutes(totalExtraMinutes)}',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canExport ? () => _downloadPdf(docs) : null,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Descargar PDF'),
                      ),
                    ),
                    if (mode == 1) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Resumen diario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...sortedEntries.map((entry) {
                        final ordinary = _ordinaryMinutes(entry.value);
                        final extra = _extraMinutes(entry.value);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.today),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        dfDay.format(entry.key),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Total trabajado: ${_formatMinutes(entry.value)}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ordinarias: ${_formatMinutes(ordinary)}',
                                ),
                                if (extra > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Extras: ${_formatMinutes(extra)}',
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 10),
                    const Text(
                      'Fichajes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...punchesDesc.map((p) {
                      final isIn = p.type == 'in';
                      final fromIncident = p.source == 'incident';

                      String title = isIn ? 'Entrada' : 'Salida';

                      if (fromIncident) {
                        title = '$title (incidencia aprobada)';
                      }

                      return Card(
                        child: ListTile(
                          leading: Icon(isIn ? Icons.login : Icons.logout),
                          title: Text(title),
                          subtitle: Text(
                            '${dfDay.format(p.at)} · ${dfTime.format(p.at)}',
                          ),
                          trailing: p.pendingSync
                              ? const Tooltip(
                                  message: 'Pendiente de sincronizar',
                                  child: Icon(Icons.cloud_upload),
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Punch {
  final String id;
  final String type;
  final DateTime at;
  final bool pendingSync;
  final String source;

  _Punch({
    required this.id,
    required this.type,
    required this.at,
    required this.pendingSync,
    required this.source,
  });
}