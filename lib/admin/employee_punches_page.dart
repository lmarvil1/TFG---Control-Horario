import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/repositories/punches_repository.dart';
import '../utils/app_snackbar.dart';
import '../utils/export_service.dart';
import '../utils/file_downloader.dart';
import '../utils/work_time.dart';

/// Pantalla para consultar los fichajes de empleados.

/// Permite visualizar registros diarios y mensuales,
/// además de exportarlos en CSV y PDF.
class EmployeePunchesPage extends StatefulWidget {
  const EmployeePunchesPage({super.key});

  @override
  State<EmployeePunchesPage> createState() =>
      _EmployeePunchesPageState();
}

class _EmployeePunchesPageState
    extends State<EmployeePunchesPage> {
  /// ID del empleado seleccionado.
  String? selectedEmployeeId;

  /// Nombre del empleado seleccionado.
  String? selectedEmployeeLabel;

  /// Repositorio encargado de obtener fichajes.
  final punchesRepo = PunchesRepository();

  /// Formato de fecha.
  final dfDay = DateFormat('dd/MM/yyyy');

  /// Formato de hora.
  final dfTime = DateFormat('HH:mm');

  /// Modo actual:
  /// 0 = Día
  /// 1 = Mes
  int mode = 0;

  /// Día seleccionado actualmente.
  DateTime selectedDay = DateTime.now();

  /// Mes seleccionado actualmente.
  DateTime selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Todos los fichajes descargados.
  List<_PunchItem> allPunches = [];

  /// Fichajes filtrados según el periodo seleccionado.
  List<_PunchItem> currentFiltered = [];

  /// Devuelve los fichajes filtrados
  /// convertidos a lista de mapas.
  List<Map<String, dynamic>> get _currentFilteredData =>
      currentFiltered.map((e) => e.data).toList();

  /// Selector de día.
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
        selectedDay = DateTime(
          d.year,
          d.month,
          d.day,
        );
      });
    }
  }

  /// Selector de mes.
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
        selectedMonth = DateTime(
          d.year,
          d.month,
          1,
        );
      });
    }
  }

  /// Fecha inicial del filtro.
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

  /// Fecha final exclusiva del filtro.
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
        : DateTime(start.year, start.month + 1, 1);
  }

  /// Filtra los fichajes según el rango seleccionado.
  void _applyFilter() {
    final start = _rangeStart();
    final end = _rangeEndExclusive();

    final out = allPunches.where((p) {
      final at = p.at;

      if (at == null) return false;

      return !at.isBefore(start) && at.isBefore(end);
    }).toList()

      // Orden descendente por fecha.
      ..sort((a, b) {
        final aTime =
            a.at ?? DateTime.fromMillisecondsSinceEpoch(0);

        final bTime =
            b.at ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bTime.compareTo(aTime);
      });

    currentFiltered = out;
  }

  /// Texto descriptivo del periodo seleccionado.
  String _titleLabel() {
    return mode == 0
        ? 'Día: ${dfDay.format(selectedDay)}'
        : 'Mes: ${DateFormat('MM/yyyy').format(selectedMonth)}';
  }

  /// Abre la ubicación del fichaje en Google Maps.
  Future<void> _openMaps(
    double lat,
    double lng,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Descarga los fichajes en CSV.
  Future<void> _downloadCsv() async {
    if (selectedEmployeeId == null) return;
    if (mode != 1) return;
    if (_currentFilteredData.isEmpty) return;

    try {
      // Genera los bytes del CSV.
      final Uint8List bytes =
          ExportService.buildCsvBytes(
        _currentFilteredData,
      );

      // Nombre del archivo.
      final filename =
          ExportService.buildFilenameForMonth(
        employeeLabel:
            selectedEmployeeLabel ??
            selectedEmployeeId!,
        month: selectedMonth,
        ext: 'csv',
      );

      // Descarga del archivo.
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

  /// Descarga los fichajes en PDF.
  Future<void> _downloadPdf() async {
    if (selectedEmployeeId == null) return;
    if (mode != 1) return;
    if (_currentFilteredData.isEmpty) return;

    try {
      // Genera el PDF.
      final Uint8List pdfBytes =
          await ExportService.buildPdfBytes(
        punches: _currentFilteredData,

        employeeLabel:
            selectedEmployeeLabel ??
            selectedEmployeeId!,

        downloadNow: DateTime.now(),
        monthLabel: selectedMonth,
      );

      // Nombre del archivo.
      final filename =
          ExportService.buildFilenameForMonth(
        employeeLabel:
            selectedEmployeeLabel ??
            selectedEmployeeId!,
        month: selectedMonth,
        ext: 'pdf',
      );

      // Descarga del archivo.
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
    /// Stream de empleados.
    final employeesStream = FirebaseFirestore
        .instance
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .snapshots();

    /// Indica si se permite exportar.
    final canExport =
        selectedEmployeeId != null &&
        mode == 1 &&
        _currentFilteredData.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fichajes por empleado',
        ),

        actions: [
          /// Botón descarga CSV.
          IconButton(
            tooltip: mode == 1
                ? 'Descargar CSV'
                : 'La descarga CSV solo está disponible por mes',
            onPressed: canExport ? _downloadCsv : null,
            icon: const Icon(Icons.table_view),
          ),

          /// Botón descarga PDF.
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
          /// Selector de empleado.
          Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: employeesStream,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                final docs = snap.data!.docs;

                return DropdownButtonFormField<String>(
                  initialValue: selectedEmployeeId,
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

                    final doc = docs.firstWhere(
                      (d) => d.id == v,
                    );

                    final data = doc.data();

                    final label =
                        (data['name'] ?? '').toString();

                    setState(() {
                      selectedEmployeeId = v;
                      selectedEmployeeLabel = label;

                      mode = 0;

                      selectedDay = DateTime.now();

                      selectedMonth = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        1,
                      );

                      allPunches = [];
                      currentFiltered = [];
                    });
                  },
                );
              },
            ),
          ),

          /// Mensaje inicial si no hay empleado seleccionado.
          if (selectedEmployeeId == null)
            const Expanded(
              child: Center(
                child: Text(
                  'Selecciona un empleado',
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  /// Controles de filtros.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        /// Selector Día / Mes.
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
                              icon: Icon(
                                Icons.calendar_month,
                              ),
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) {
                            setState(() {
                              mode = s.first;
                            });
                          },
                        ),

                        const SizedBox(height: 10),

                        /// Selector de fecha.
                        OutlinedButton.icon(
                          onPressed:
                              mode == 0 ? _pickDay : _pickMonth,
                          icon: const Icon(
                            Icons.filter_alt,
                          ),
                          label: Text(
                            _titleLabel(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// Lista de fichajes.
                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: punchesRepo.streamPunches(
                        selectedEmployeeId!,
                        includeMetadata: true,
                      ),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                12,
                              ),
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

                        /// Conversión de documentos.
                        allPunches = docs.map((d) {
                          return _PunchItem(
                            data: d.data(),
                            pendingSync:
                                d.metadata.hasPendingWrites,
                          );
                        }).toList();

                        // Aplicación del filtro.
                        _applyFilter();

                        final calcData =
                            _currentFilteredData.toList();

                        /// Minutos trabajados por día.
                        final perDayMinutes =
                            WorkTime.minutesByDay(calcData);

                        final totalMinutes =
                            WorkTime.totalMinutes(perDayMinutes);

                        /// Minutos ordinarios totales.
                        final totalOrdinaryMinutes =
                            WorkTime.totalOrdinaryMinutes(
                          perDayMinutes,
                        );

                        /// Minutos extra totales.
                        final totalExtraMinutes =
                            WorkTime.totalExtraMinutes(
                          perDayMinutes,
                        );

                        /// Resumen ordenado por día.
                        final sortedEntries =
                            perDayMinutes.entries.toList()
                              ..sort(
                                (a, b) => b.key.compareTo(
                                  a.key,
                                ),
                              );

                        return ListView(
                          padding: const EdgeInsets.all(
                            12,
                          ),
                          children: [
                            /// Tarjeta resumen principal.
                            Card(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total trabajado (${mode == 0 ? "día" : "mes"})',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),

                                    const SizedBox(
                                      height: 6,
                                    ),

                                    Text(
                                      WorkTime.formatHM(
                                        totalMinutes,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge,
                                    ),

                                    const SizedBox(
                                      height: 10,
                                    ),

                                    Text(
                                      'Ordinarias: ${WorkTime.formatHM(totalOrdinaryMinutes)}',
                                    ),

                                    if (totalExtraMinutes > 0) ...[
                                      const SizedBox(
                                        height: 4,
                                      ),
                                      Text(
                                        'Extras: ${WorkTime.formatHM(totalExtraMinutes)}',
                                        style:
                                            const TextStyle(
                                          color: Colors.orange,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            /// Resumen diario mensual.
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

                              if (sortedEntries.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'No hay fichajes en este mes.',
                                  ),
                                )
                              else
                                ...sortedEntries.map((e) {
                                  final ordinary =
                                      WorkTime.ordinaryMinutes(
                                    e.value,
                                  );

                                  final extra =
                                      WorkTime.extraMinutes(
                                    e.value,
                                  );

                                  return Card(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          /// Cabecera del día.
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.today,
                                              ),

                                              const SizedBox(
                                                width: 12,
                                              ),

                                              Expanded(
                                                child: Text(
                                                  dfDay.format(
                                                    e.key,
                                                  ),
                                                  style:
                                                      const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(
                                            height: 8,
                                          ),

                                          Text(
                                            'Total trabajado: ${WorkTime.formatHM(e.value)}',
                                          ),

                                          const SizedBox(
                                            height: 4,
                                          ),

                                          Text(
                                            'Ordinarias: ${WorkTime.formatHM(ordinary)}',
                                          ),

                                          if (extra > 0) ...[
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              'Extras: ${WorkTime.formatHM(extra)}',
                                              style:
                                                  const TextStyle(
                                                color: Colors.orange,
                                                fontWeight:
                                                    FontWeight.w600,
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

                            /// Título de fichajes.
                            const Text(
                              'Fichajes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 6),

                            /// Mensaje sin fichajes.
                            if (currentFiltered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No hay fichajes en este periodo.',
                                  ),
                                ),
                              )
                            else
                              ...currentFiltered.map((item) {
                                final ts =
                                    item.data['at'] as Timestamp?;

                                final at =
                                    ts?.toDate() ?? DateTime.now();

                                final type =
                                    (item.data['type'] ?? '')
                                        .toString();

                                final isIn = type == 'in';

                                final source =
                                    (item.data['source'] ?? 'mobile')
                                        .toString();

                                final fromIncident =
                                    source == 'incident';

                                /// Texto principal.
                                String title =
                                    isIn ? 'Entrada' : 'Salida';

                                if (fromIncident) {
                                  title =
                                      '$title (incidencia aprobada)';
                                }

                                /// Ubicación del fichaje.
                                final loc =
                                    item.data['location']
                                        as Map<String, dynamic>?;

                                final double? lat =
                                    (loc?['lat'] as num?)
                                        ?.toDouble();

                                final double? lng =
                                    (loc?['lng'] as num?)
                                        ?.toDouble();

                                Widget? trailing;

                                /// Botón abrir Maps.
                                if (lat != null && lng != null) {
                                  trailing = IconButton(
                                    tooltip: 'Abrir en Maps',
                                    icon: const Icon(
                                      Icons.location_on,
                                    ),
                                    onPressed: () => _openMaps(
                                      lat,
                                      lng,
                                    ),
                                  );
                                }

                                /// Indicador pendiente sincronización.
                                if (item.pendingSync) {
                                  trailing =
                                      const Tooltip(
                                    message:
                                        'Pendiente de sincronizar',
                                    child: Icon(
                                      Icons.cloud_upload,
                                    ),
                                  );
                                }

                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      isIn
                                          ? Icons.login
                                          : Icons.logout,
                                    ),
                                    title: Text(
                                      title,
                                    ),
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

/// Modelo auxiliar para representar fichajes.
class _PunchItem {
  /// Datos del fichaje.
  final Map<String, dynamic> data;

  /// Indica si el fichaje está pendiente de sincronización.
  final bool pendingSync;

  _PunchItem({
    required this.data,
    required this.pendingSync,
  });

  /// Fecha del fichaje.
  DateTime? get at {
    final ts = data['at'];

    if (ts is Timestamp) {
      return ts.toDate();
    }

    return null;
  }
}