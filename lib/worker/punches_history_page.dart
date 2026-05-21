import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_snackbar.dart';
import '../utils/export_service.dart';
import '../utils/file_downloader.dart';
import '../utils/work_time.dart';

/// Pantalla encargada de mostrar el historial de fichajes.

/// Permite:
/// - Consultar fichajes diarios o mensuales
/// - Calcular horas trabajadas
/// - Calcular horas ordinarias y extraordinarias
/// - Exportar el historial mensual en PDF
class PunchesHistoryPage extends StatefulWidget {
  /// Identificador del empleado asociado.
  final String employeeId;

  const PunchesHistoryPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<PunchesHistoryPage> createState() =>
      _PunchesHistoryPageState();
}

class _PunchesHistoryPageState
    extends State<PunchesHistoryPage> {
  /// Formateador de fechas.
  final dfDay = DateFormat('dd/MM/yyyy');

  /// Formateador de horas.
  final dfTime = DateFormat('HH:mm');

  /// Modo seleccionado:
  /// 0 = Día
  /// 1 = Mes
  int mode = 0;

  /// Día actualmente seleccionado.
  DateTime selectedDay = DateTime.now();

  /// Mes actualmente seleccionado.
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  /// Nombre visible del empleado.
  String? employeeLabel;

  @override
  void initState() {
    super.initState();
    _loadEmployeeLabel();
  }

  /// Obtiene el nombre del empleado desde Firestore.
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

  /// Permite seleccionar un día concreto.
  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedDay,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );

    if (d != null) {
      setState(() {
        selectedDay = DateTime(d.year, d.month, d.day);
      });
    }
  }

  /// Permite seleccionar un mes concreto.
  Future<void> _pickMonth() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );

    if (d != null) {
      setState(() {
        selectedMonth = DateTime(d.year, d.month, 1);
      });
    }
  }

  /// Devuelve la fecha inicial del rango consultado.
  DateTime _rangeStart() {
    if (mode == 0) {
      return DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      );
    }

    return DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );
  }

  /// Devuelve la fecha final exclusiva del rango consultado.
  DateTime _rangeEndExclusive() {
    if (mode == 0) {
      return _rangeStart().add(
        const Duration(days: 1),
      );
    }

    final start = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    return (start.month == 12)
        ? DateTime(start.year + 1, 1, 1)
        : DateTime(
            start.year,
            start.month + 1,
            1,
          );
  }

  /// Genera y descarga un PDF con el historial mensual.
  Future<void> _downloadPdf(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (mode != 1 || docs.isEmpty) {
      return;
    }

    try {
      final punches = docs.map((d) => d.data()).toList();

      final label = (employeeLabel ?? widget.employeeId).trim();

      final Uint8List pdfBytes = await ExportService.buildPdfBytes(
        punches: punches,
        employeeLabel: label,
        downloadNow: DateTime.now(),
        monthLabel: selectedMonth,
      );

      final filename = ExportService.buildFilenameForMonth(
        employeeLabel: label,
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

    /// Consulta de fichajes dentro del rango seleccionado.
    final query = FirebaseFirestore.instance
        .collection('punches')
        .doc(widget.employeeId)
        .collection('items')
        .where(
          'at',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'at',
          isLessThan: Timestamp.fromDate(end),
        )
        .orderBy('at', descending: true);

    final title = mode == 0
        ? 'Día: ${dfDay.format(selectedDay)}'
        : 'Mes: ${DateFormat('MM/yyyy').format(selectedMonth)}';

    return SafeArea(
      child: Column(
        children: [
          /// Panel superior de filtros.
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

                /// Selector entre vista diaria y mensual.
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
                  onSelectionChanged: (s) {
                    setState(() => mode = s.first);
                  },
                ),

                const SizedBox(height: 10),

                /// Selector de fecha o mes.
                OutlinedButton.icon(
                  onPressed: mode == 0 ? _pickDay : _pickMonth,
                  icon: const Icon(Icons.filter_alt),
                  label: Text(title),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Error: ${snap.error}',
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay fichajes en este periodo.',
                    ),
                  );
                }

                final punchMaps =
                    docs.map((d) => d.data()).toList();

                /// Cálculo centralizado de horas usando WorkTime.
                final perDayMinutes =
                    WorkTime.minutesByDay(punchMaps);

                final totalMinutes =
                    WorkTime.totalMinutes(perDayMinutes);

                final totalOrdinaryMinutes =
                    WorkTime.totalOrdinaryMinutes(perDayMinutes);

                final totalExtraMinutes =
                    WorkTime.totalExtraMinutes(perDayMinutes);

                /// Conversión de documentos a objetos internos.
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

                /// Ordena el resumen diario.
                final sortedEntries =
                    perDayMinutes.entries.toList()
                      ..sort(
                        (a, b) => b.key.compareTo(a.key),
                      );

                final canExport = mode == 1 && docs.isNotEmpty;

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    /// Tarjeta resumen de horas trabajadas.
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),

                            const SizedBox(height: 6),

                            Text(
                              WorkTime.formatHM(totalMinutes),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge,
                            ),

                            const SizedBox(height: 10),

                            Text(
                              'Ordinarias: ${WorkTime.formatHM(totalOrdinaryMinutes)}',
                            ),

                            if (totalExtraMinutes > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Extras: ${WorkTime.formatHM(totalExtraMinutes)}',
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

                    /// Botón para descargar PDF.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            canExport ? () => _downloadPdf(docs) : null,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Descargar PDF'),
                      ),
                    ),

                    /// Resumen diario en modo mensual.
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
                        final ordinary =
                            WorkTime.ordinaryMinutes(entry.value);

                        final extra =
                            WorkTime.extraMinutes(entry.value);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
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
                                  'Total trabajado: ${WorkTime.formatHM(entry.value)}',
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Ordinarias: ${WorkTime.formatHM(ordinary)}',
                                ),

                                if (extra > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Extras: ${WorkTime.formatHM(extra)}',
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

                    /// Lista detallada de fichajes.
                    ...punchesDesc.map((p) {
                      final isIn = p.type == 'in';

                      final fromIncident = p.source == 'incident';

                      String title = isIn ? 'Entrada' : 'Salida';

                      if (fromIncident) {
                        title = '$title (incidencia aprobada)';
                      }

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isIn ? Icons.login : Icons.logout,
                          ),
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

/// Modelo interno utilizado para representar un fichaje.
class _Punch {
  /// Identificador del fichaje.
  final String id;

  /// Tipo de fichaje:
  /// - in
  /// - out
  final String type;

  /// Fecha y hora del fichaje.
  final DateTime at;

  /// Indica si el fichaje aún no se ha sincronizado.
  final bool pendingSync;

  /// Origen del fichaje.
  final String source;

  _Punch({
    required this.id,
    required this.type,
    required this.at,
    required this.pendingSync,
    required this.source,
  });
}