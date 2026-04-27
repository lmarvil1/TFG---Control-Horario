import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_snackbar.dart';

class AdminJustificationsPage extends StatefulWidget {
  final bool readOnly;

  const AdminJustificationsPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<AdminJustificationsPage> createState() => _AdminJustificationsPageState();
}

class _AdminJustificationsPageState extends State<AdminJustificationsPage> {
  final df = DateFormat('dd/MM/yyyy');

  final searchCtrl = TextEditingController();
  String? selectedEmployeeId;

  DateTime? fromDate;
  DateTime? toDate;

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => toDate = picked);
  }

  void _clearDates() {
    setState(() {
      fromDate = null;
      toDate = null;
    });
  }

  DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 0, 0, 0);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<String> _downloadToAppFolder({
    required String url,
    required String filename,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file = File('${dir.path}/$safeName');

    await Dio().download(url, file.path);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final employeesStream = FirebaseFirestore.instance
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.readOnly ? 'Justificantes' : 'Justificantes'),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: employeesStream,
          builder: (context, empSnap) {
            if (empSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Error cargando empleados:\n${empSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!empSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final empDocs = empSnap.data!.docs;

            final Map<String, Map<String, String>> empMap = {
              for (final d in empDocs)
                d.id: {
                  'name': (d.data()['name'] ?? '').toString(),
                  'dni': (d.data()['dni'] ?? '').toString(),
                }
            };

            Query<Map<String, dynamic>> q = FirebaseFirestore.instance
                .collection('absence_justifications');

            if (selectedEmployeeId != null && selectedEmployeeId!.isNotEmpty) {
              q = q.where('employeeId', isEqualTo: selectedEmployeeId);
            }

            if (fromDate != null) {
              q = q.where(
                'date',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(_startOfDay(fromDate!)),
              );
            }

            if (toDate != null) {
              q = q.where(
                'date',
                isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay(toDate!)),
              );
            }

            q = q.orderBy('date', descending: true).orderBy(
                  'createdAt',
                  descending: true,
                );

            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: constraints.maxWidth >= 600
                                      ? constraints.maxWidth - 260
                                      : constraints.maxWidth,
                                  child: TextField(
                                    controller: searchCtrl,
                                    decoration: const InputDecoration(
                                      labelText:
                                          'Buscar (nombre, DNI, motivo, archivo)',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth >= 600
                                      ? 240
                                      : constraints.maxWidth,
                                  child: DropdownButtonFormField<String?>(
                                    value: selectedEmployeeId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Empleado',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Todos'),
                                      ),
                                      ...empDocs.map((d) {
                                        final e = d.data();
                                        final name =
                                            (e['name'] ?? '').toString();
                                        final dni = (e['dni'] ?? '').toString();
                                        final label = dni.isNotEmpty
                                            ? '$name ($dni)'
                                            : name;

                                        return DropdownMenuItem<String?>(
                                          value: d.id,
                                          child: Text(
                                            label,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => selectedEmployeeId = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: constraints.maxWidth >= 600
                                      ? (constraints.maxWidth / 2) - 10
                                      : constraints.maxWidth,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickFromDate,
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      fromDate == null
                                          ? 'Desde'
                                          : df.format(fromDate!),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth >= 600
                                      ? (constraints.maxWidth / 2) - 10
                                      : constraints.maxWidth,
                                  child: OutlinedButton.icon(
                                    onPressed: _pickToDate,
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      toDate == null
                                          ? 'Hasta'
                                          : df.format(toDate!),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Limpiar fechas',
                                  onPressed: (fromDate != null || toDate != null)
                                      ? _clearDates
                                      : null,
                                  icon: const Icon(Icons.clear),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: q.snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Error cargando justificantes:\n${snap.error}',
                                textAlign: TextAlign.center,
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
                            child: Text('No hay justificantes.'),
                          );
                        }

                        final queryText = searchCtrl.text.trim().toLowerCase();

                        final filtered = docs.where((doc) {
                          if (queryText.isEmpty) return true;

                          final data = doc.data();
                          final employeeId =
                              (data['employeeId'] ?? '').toString();
                          final reason = (data['reason'] ?? '').toString();
                          final filename = (data['filename'] ?? '').toString();

                          final emp = empMap[employeeId];
                          final empName = emp?['name'] ?? '';
                          final empDni = emp?['dni'] ?? '';

                          final haystack =
                              '$empName $empDni $reason $filename'.toLowerCase();

                          return haystack.contains(queryText);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No hay resultados con ese filtro/búsqueda.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final data = filtered[i].data();

                            final employeeId =
                                (data['employeeId'] ?? '').toString();
                            final reason = (data['reason'] ?? '').toString();
                            final filename =
                                (data['filename'] ?? '').toString();
                            final url =
                                (data['downloadUrl'] ?? '').toString();
                            final contentType =
                                (data['contentType'] ?? '').toString();

                            final dateTs = data['date'] as Timestamp?;
                            final date = dateTs?.toDate();

                            final emp = empMap[employeeId];
                            final empName =
                                (emp?['name'] ?? 'Empleado desconocido').trim();

                            final isPdf = contentType.contains('pdf') ||
                                filename.toLowerCase().endsWith('.pdf');

                            final cleanReason = reason.trim();
                            final titleText = cleanReason.isNotEmpty
                                ? '$empName - $cleanReason'
                                : empName;

                            final subtitleText =
                                '${date != null ? df.format(date) : "-"} · $filename';

                            return ListTile(
                              leading: Icon(
                                isPdf
                                    ? Icons.picture_as_pdf
                                    : Icons.image,
                              ),
                              title: Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                subtitleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Opciones',
                                onSelected: (value) async {
                                  if (url.isEmpty) return;

                                  if (value == 'open') {
                                    await _openUrl(url);
                                    return;
                                  }

                                  if (value == 'download') {
                                    try {
                                      if (kIsWeb) {
                                        await _openUrl(url);
                                        if (context.mounted) {
                                          AppSnackbar.show(
                                            context,
                                            'Abierto en el navegador (descarga desde ahí).',
                                          );
                                        }
                                        return;
                                      }

                                      final path =
                                          await _downloadToAppFolder(
                                        url: url,
                                        filename: filename.isNotEmpty
                                            ? filename
                                            : 'justificante',
                                      );

                                      await OpenFilex.open(path);

                                      if (context.mounted) {
                                        AppSnackbar.show(
                                          context,
                                          'Descargado en: $path',
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        AppSnackbar.show(
                                          context,
                                          'Error descargando: $e',
                                          isError: true,
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'open',
                                    enabled: url.isNotEmpty,
                                    child: const Row(
                                      children: [
                                        Icon(Icons.open_in_new, size: 18),
                                        SizedBox(width: 8),
                                        Text('Abrir'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'download',
                                    enabled: url.isNotEmpty,
                                    child: const Row(
                                      children: [
                                        Icon(Icons.download, size: 18),
                                        SizedBox(width: 8),
                                        Text('Descargar'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: url.isEmpty ? null : () => _openUrl(url),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}