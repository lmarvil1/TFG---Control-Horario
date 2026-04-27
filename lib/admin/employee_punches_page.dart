import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/repositories/punches_repository.dart';
import '../utils/app_snackbar.dart';
import '../utils/export_service.dart';
import '../utils/file_downloader.dart';

class EmployeePunchesPage extends StatefulWidget {
  const EmployeePunchesPage({super.key});

  @override
  State<EmployeePunchesPage> createState() => _EmployeePunchesPageState();
}

class _EmployeePunchesPageState extends State<EmployeePunchesPage> {
  String? selectedEmployeeId;
  String? selectedEmployeeLabel;

  final punchesRepo = PunchesRepository();

  final dfDay = DateFormat('dd/MM/yyyy');
  final dfTime = DateFormat('HH:mm');

  /// 0 = Día | 1 = Mes
  int mode = 0;

  DateTime selectedDay = DateTime.now();
  DateTime selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<_PunchItem> allPunches = [];
  List<_PunchItem> currentFiltered = [];

  List<Map<String, dynamic>> get _currentFilteredData =>
      currentFiltered.map((e) => e.data).toList();

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

  void _applyFilter() {
    final start = _rangeStart();
    final end = _rangeEndExclusive();

    final out = allPunches.where((p) {
      final at = p.at;
      if (at == null) return false;
      return !at.isBefore(start) && at.isBefore(end);
    }).toList()
      ..sort((a, b) {
        final aTime = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    currentFiltered = out;
  }

  int _workedMinutes(List<Map<String, dynamic>> punches) {
    int minutes = 0;
    DateTime? openIn;

    for (final p in punches) {
      final ts = p['at'];
      if (ts is! Timestamp) continue;
      final at = ts.toDate();

      final type = (p['type'] ?? '').toString();
      if (type == 'in') {
        openIn = at;
      } else if (type == 'out') {
        if (openIn != null && at.isAfter(openIn)) {
          minutes += at.difference(openIn).inMinutes;
          openIn = null;
        }
      }
    }
    return minutes;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  String _titleLabel() {
    return mode == 0
        ? 'Día: ${dfDay.format(selectedDay)}'
        : 'Mes: ${DateFormat('MM/yyyy').format(selectedMonth)}';
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadCsv() async {
    if (selectedEmployeeId == null) return;
    if (mode != 1) return;
    if (_currentFilteredData.isEmpty) return;

    try {
      final Uint8List bytes = ExportService.buildCsvBytes(_currentFilteredData);

      final filename = ExportService.buildFilenameForMonth(
        employeeLabel: selectedEmployeeLabel ?? selectedEmployeeId!,
        month: selectedMonth,
        ext: 'csv',
      );

      await downloadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv;charset=utf-8',
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'CSV descargado (${_currentFilteredData.length} registros).',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        'Error exportando CSV: $e',
        isError: true,
      );
    }
  }

  Future<void> _downloadPdf() async {
    if (selectedEmployeeId == null) return;
    if (mode != 1) return;
    if (_currentFilteredData.isEmpty) return;

    try {
      final Uint8List pdfBytes = await ExportService.buildPdfBytes(
        punches: _currentFilteredData,
        employeeLabel: selectedEmployeeLabel ?? selectedEmployeeId!,
        downloadNow: DateTime.now(),
        monthLabel: selectedMonth,
      );

      final filename = ExportService.buildFilenameForMonth(
        employeeLabel: selectedEmployeeLabel ?? selectedEmployeeId!,
        month: selectedMonth,
        ext: 'pdf',
      );

      await downloadBytes(
        bytes: pdfBytes,
        filename: filename,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        'PDF descargado (${_currentFilteredData.length} registros).',
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
    final employeesStream = FirebaseFirestore.instance
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .snapshots();

    final canExport =
        selectedEmployeeId != null && mode == 1 && _currentFilteredData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fichajes por empleado'),
        actions: [
          IconButton(
            tooltip: mode == 1
                ? 'Descargar CSV'
                : 'La descarga CSV solo está disponible por mes',
            onPressed: canExport ? _downloadCsv : null,
            icon: const Icon(Icons.table_view),
          ),
          IconButton(
            tooltip: mode == 1
                ? 'Descargar PDF'
                : 'La descarga PDF solo está disponible por mes',
            onPressed: canExport ? _downloadPdf : null,
            icon: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: employeesStream,
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                final docs = snap.data!.docs;

                return DropdownButtonFormField<String>(
                  value: selectedEmployeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Selecciona empleado',
                    border: OutlineInputBorder(),
                  ),
                  items: docs.map((d) {
                    final data = d.data();
                    final label = "${data['name']}";
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;

                    final doc = docs.firstWhere((d) => d.id == v);
                    final data = doc.data();
                    final label = (data['name'] ?? '').toString();

                    setState(() {
                      selectedEmployeeId = v;
                      selectedEmployeeLabel = label;
                      mode = 0;
                      selectedDay = DateTime.now();
                      selectedMonth =
                          DateTime(DateTime.now().year, DateTime.now().month, 1);
                      allPunches = [];
                      currentFiltered = [];
                    });
                  },
                );
              },
            ),
          ),
          if (selectedEmployeeId == null)
            const Expanded(
              child: Center(child: Text('Selecciona un empleado')),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          onSelectionChanged: (s) =>
                              setState(() => mode = s.first),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: mode == 0 ? _pickDay : _pickMonth,
                          icon: const Icon(Icons.filter_alt),
                          label: Text(_titleLabel()),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: punchesRepo.streamPunches(
                        selectedEmployeeId!,
                        includeMetadata: true,
                      ),
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
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final docs = snap.data!.docs;

                        allPunches = docs.map((d) {
                          return _PunchItem(
                            data: d.data(),
                            pendingSync: d.metadata.hasPendingWrites,
                          );
                        }).toList();

                        _applyFilter();

                        final ascForCalc = List<_PunchItem>.from(currentFiltered)
                          ..sort((a, b) {
                            final aTime =
                                a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
                            final bTime =
                                b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
                            return aTime.compareTo(bTime);
                          });

                        final ascCalcData = ascForCalc.map((e) => e.data).toList();

                        final perDayMinutes = <DateTime, int>{};
                        int totalMinutes;

                        if (mode == 1) {
                          final grouped = <DateTime, List<Map<String, dynamic>>>{};

                          for (final p in ascCalcData) {
                            final ts = p['at'] as Timestamp?;
                            final at = ts?.toDate();
                            if (at == null) continue;
                            final dayKey = DateTime(at.year, at.month, at.day);
                            grouped.putIfAbsent(dayKey, () => []).add(p);
                          }

                          grouped.forEach((day, list) {
                            list.sort((a, b) {
                              final aTime = (a['at'] as Timestamp).toDate();
                              final bTime = (b['at'] as Timestamp).toDate();
                              return aTime.compareTo(bTime);
                            });
                            perDayMinutes[day] = _workedMinutes(list);
                          });

                          totalMinutes =
                              perDayMinutes.values.fold<int>(0, (a, b) => a + b);
                        } else {
                          totalMinutes = _workedMinutes(ascCalcData);
                        }

                        final sortedEntries = perDayMinutes.entries.toList()
                          ..sort((a, b) => b.key.compareTo(a.key));

                        return ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.schedule),
                                title: Text(
                                  'Total trabajado (${mode == 0 ? "día" : "mes"})',
                                ),
                                subtitle: Text(_formatMinutes(totalMinutes)),
                              ),
                            ),
                            if (mode == 1) ...[
                              const SizedBox(height: 10),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Totales diarios del mes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (sortedEntries.isEmpty)
                                        const Text(
                                          'No hay fichajes en este mes.',
                                        )
                                      else
                                        ...sortedEntries.map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(dfDay.format(e.key)),
                                                Text(_formatMinutes(e.value)),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
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
                            if (currentFiltered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('No hay fichajes en este periodo.'),
                                ),
                              )
                            else
                              ...currentFiltered.map((item) {
                                final ts = item.data['at'] as Timestamp?;
                                final at = ts?.toDate() ?? DateTime.now();
                                final type = (item.data['type'] ?? '').toString();
                                final isIn = type == 'in';

                                final source =
                                    (item.data['source'] ?? 'mobile').toString();
                                final fromIncident = source == 'incident';

                                String title = isIn ? 'Entrada' : 'Salida';
                                if (fromIncident) {
                                  title = '$title (incidencia aprobada)';
                                }

                                final loc =
                                    item.data['location'] as Map<String, dynamic>?;
                                final double? lat =
                                    (loc?['lat'] as num?)?.toDouble();
                                final double? lng =
                                    (loc?['lng'] as num?)?.toDouble();

                                Widget? trailing;

                                if (lat != null && lng != null) {
                                  trailing = IconButton(
                                    tooltip: 'Abrir en Maps',
                                    icon: const Icon(Icons.location_on),
                                    onPressed: () => _openMaps(lat, lng),
                                  );
                                }

                                if (item.pendingSync) {
                                  trailing = const Tooltip(
                                    message: 'Pendiente de sincronizar',
                                    child: Icon(Icons.cloud_upload),
                                  );
                                }

                                return Card(
                                  child: ListTile(
                                    leading:
                                        Icon(isIn ? Icons.login : Icons.logout),
                                    title: Text(title),
                                    subtitle: Text(
                                      '${dfDay.format(at)} · ${dfTime.format(at)}',
                                    ),
                                    trailing: trailing,
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
            ),
        ],
      ),
    );
  }
}

class _PunchItem {
  final Map<String, dynamic> data;
  final bool pendingSync;

  _PunchItem({
    required this.data,
    required this.pendingSync,
  });

  DateTime? get at {
    final ts = data['at'];
    if (ts is Timestamp) return ts.toDate();
    return null;
  }
}