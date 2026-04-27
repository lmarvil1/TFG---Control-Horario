import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/repositories/payrolls_repository.dart';
import '../utils/app_snackbar.dart';

class WorkerPayrollsPage extends StatefulWidget {
  final String employeeId;

  const WorkerPayrollsPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<WorkerPayrollsPage> createState() => _WorkerPayrollsPageState();
}

class _WorkerPayrollsPageState extends State<WorkerPayrollsPage> {
  final repo = PayrollsRepository();

  int? filterMonth;
  int? filterYear;

  final years = List<int>.generate(6, (i) => DateTime.now().year - 1 + i);

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: filterMonth,
                        decoration: const InputDecoration(
                          labelText: 'Mes',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...List.generate(12, (i) => i + 1).map(
                            (m) => DropdownMenuItem<int?>(
                              value: m,
                              child: Text(m.toString().padLeft(2, '0')),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => filterMonth = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: filterYear,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ...years.map(
                            (y) => DropdownMenuItem<int?>(
                              value: y,
                              child: Text('$y'),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => filterYear = v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<PayrollItem>>(
                stream: repo.streamEmployeePayrolls(
                  employeeId: widget.employeeId,
                  month: filterMonth,
                  year: filterYear,
                ),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Center(child: Text('No tienes nóminas.'));
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(
                          p.periodLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          p.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'open') {
                              await _openUrl(p.downloadUrl);
                              return;
                            }

                            if (value == 'download') {
                              try {
                                if (kIsWeb) {
                                  await _openUrl(p.downloadUrl);
                                  return;
                                }

                                final path = await _downloadToAppFolder(
                                  url: p.downloadUrl,
                                  filename: p.fileName,
                                );
                                await OpenFilex.open(path);
                              } catch (e) {
                                if (!context.mounted) return;
                                AppSnackbar.show(
                                  context,
                                  'Error descargando: $e',
                                  isError: true,
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new, size: 18),
                                  SizedBox(width: 8),
                                  Text('Abrir'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'download',
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 18),
                                  SizedBox(width: 8),
                                  Text('Descargar'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openUrl(p.downloadUrl),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}