import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/repositories/payrolls_repository.dart';
import '../utils/app_snackbar.dart';

/// Pantalla de gestión de nóminas.

/// Permite subir, filtrar, abrir y descargar
/// nóminas de los trabajadores.
class AdminPayrollsPage extends StatefulWidget {
  const AdminPayrollsPage({super.key});

  @override
  State<AdminPayrollsPage> createState() =>
      _AdminPayrollsPageState();
}

class _AdminPayrollsPageState
    extends State<AdminPayrollsPage> {

  /// Repositorio de nóminas.
  final repo = PayrollsRepository();

  /// Empleado seleccionado para subir nómina.
  String? selectedEmployeeId;

  /// Nombre del empleado seleccionado.
  String? selectedEmployeeName;

  /// Mes seleccionado para la nómina.
  int? selectedMonth;

  /// Año seleccionado para la nómina.
  int? selectedYear;

  /// Filtro por empleado.
  String? filterEmployeeId;

  /// Filtro por mes.
  int? filterMonth;

  /// Filtro por año.
  int? filterYear;

  /// Archivo PDF seleccionado.
  PlatformFile? picked;

  /// Indica si se está subiendo la nómina.
  bool uploading = false;

  /// Mensaje de error.
  String? error;

  /// Lista de años disponibles.
  final years = List<int>.generate(
    6,
    (i) => DateTime.now().year - 1 + i,
  );

  /// Selector de archivo PDF.
  Future<void> _pickPdf() async {

    setState(() {
      picked = null;
      error = null;
    });

    final res =
        await FilePicker.platform.pickFiles(
      withData: true,

      type: FileType.custom,

      allowedExtensions: ['pdf'],
    );

    if (res == null ||
        res.files.isEmpty) {

      return;
    }

    final f = res.files.first;

    // Validación de bytes.
    if (f.bytes == null) {

      setState(() {
        error =
            'No se pudieron leer los bytes del PDF.';
      });

      return;
    }

    setState(() {
      picked = f;
    });
  }

  /// Sube la nómina seleccionada.
  Future<void> _upload() async {

    // Validación empleado.
    if (selectedEmployeeId == null ||
        selectedEmployeeName == null) {

      setState(() {
        error =
            'Selecciona un trabajador.';
      });

      return;
    }

    // Validación periodo.
    if (selectedMonth == null ||
        selectedYear == null) {

      setState(() {
        error =
            'Selecciona mes y año.';
      });

      return;
    }

    // Validación archivo.
    if (picked == null) {

      setState(() {
        error =
            'Selecciona un PDF.';
      });

      return;
    }

    setState(() {
      uploading = true;
      error = null;
    });

    try {

      // Subida de nómina.
      await repo.uploadPayroll(
        employeeId:
            selectedEmployeeId!,

        employeeName:
            selectedEmployeeName!,

        month:
            selectedMonth!,

        year:
            selectedYear!,

        filename:
            picked!.name,

        bytes:
            picked!.bytes!,
      );

      if (!mounted) return;

      setState(() {
        picked = null;
      });

      AppSnackbar.show(
        context,
        'Nómina subida correctamente',
      );

    } catch (e) {

      if (!mounted) return;

      setState(() {
        error =
            'Error subiendo nómina: $e';
      });

    } finally {

      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  /// Abre una URL externa.
  Future<void> _openUrl(String url) async {

    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Descarga el archivo en la carpeta local.
  Future<String> _downloadToAppFolder({
    required String url,
    required String filename,
  }) async {

    final dir =
        await getApplicationDocumentsDirectory();

    // Limpia caracteres inválidos.
    final safeName = filename.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final file =
        File('${dir.path}/$safeName');

    // Descarga mediante Dio.
    await Dio().download(
      url,
      file.path,
    );

    return file.path;
  }

  @override
  Widget build(BuildContext context) {

    /// Stream de empleados.
    final employeesStream =
        FirebaseFirestore.instance
            .collection('employees')
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nóminas'),
      ),

      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: employeesStream,

          builder: (context, empSnap) {

            // Error cargando empleados.
            if (empSnap.hasError) {
              return Center(
                child: Text(
                  'Error cargando empleados: ${empSnap.error}',
                ),
              );
            }

            // Indicador de carga.
            if (!empSnap.hasData) {
              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final empDocs =
                empSnap.data!.docs;

            return Padding(
              padding:
                  const EdgeInsets.all(12),

              child: Column(
                children: [

                  /// Tarjeta de subida de nóminas.
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(12),

                      child: Column(
                        children: [

                          /// Selector trabajador.
                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                selectedEmployeeId,

                            isExpanded: true,

                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Trabajador',

                              border:
                                  OutlineInputBorder(),
                            ),

                            items:
                                empDocs.map((d) {

                              final data =
                                  d.data();

                              final name =
                                  (data['name'] ??
                                          '')
                                      .toString();

                              return DropdownMenuItem<
                                  String>(
                                value: d.id,

                                child: Text(
                                  name,

                                  maxLines: 1,

                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              );
                            }).toList(),

                            onChanged:
                                uploading
                                    ? null
                                    : (v) {
                                        final matches =
                                            empDocs.where(
                                              (e) => e.id == v,
                                            );

                                        final doc =
                                            matches.isEmpty
                                                ? null
                                                : matches.first;

                                        setState(() {
                                          selectedEmployeeId =
                                              v;

                                          selectedEmployeeName =
                                              doc
                                                      ?.data()['name']
                                                      ?.toString() ??
                                                  '';
                                        });
                                      },
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          /// Selector mes y año.
                          Row(
                            children: [

                              /// Selector mes.
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                        int>(
                                  initialValue:
                                      selectedMonth,

                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Mes',

                                    border:
                                        OutlineInputBorder(),
                                  ),

                                  items: List.generate(
                                    12,
                                    (i) => i + 1,
                                  )
                                      .map(
                                        (m) =>
                                            DropdownMenuItem<
                                                int>(
                                          value:
                                              m,

                                          child:
                                              Text(
                                            m
                                                .toString()
                                                .padLeft(
                                                  2,
                                                  '0',
                                                ),
                                          ),
                                        ),
                                      )
                                      .toList(),

                                  onChanged:
                                      uploading
                                          ? null
                                          : (v) {

                                              setState(() {
                                                selectedMonth =
                                                    v;
                                              });
                                            },
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              /// Selector año.
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                        int>(
                                  initialValue:
                                      selectedYear,

                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Año',

                                    border:
                                        OutlineInputBorder(),
                                  ),

                                  items: years
                                      .map(
                                        (y) =>
                                            DropdownMenuItem<
                                                int>(
                                          value:
                                              y,

                                          child:
                                              Text(
                                            '$y',
                                          ),
                                        ),
                                      )
                                      .toList(),

                                  onChanged:
                                      uploading
                                          ? null
                                          : (v) {

                                              setState(() {
                                                selectedYear =
                                                    v;
                                              });
                                            },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          /// Selector PDF.
                          SizedBox(
                            width:
                                double.infinity,

                            child:
                                OutlinedButton.icon(
                              onPressed:
                                  uploading
                                      ? null
                                      : _pickPdf,

                              icon:
                                  const Icon(
                                Icons.attach_file,
                              ),

                              label: Text(
                                picked == null
                                    ? 'Elegir PDF'
                                    : picked!.name,

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          /// Botón subir nómina.
                          SizedBox(
                            width:
                                double.infinity,

                            child:
                                ElevatedButton(
                              onPressed:
                                  uploading
                                      ? null
                                      : _upload,

                              child:
                                  uploading
                                      ? const SizedBox(
                                          width:
                                              18,

                                          height:
                                              18,

                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Text(
                                          'Subir nómina',
                                        ),
                            ),
                          ),

                          /// Mensaje error.
                          if (error != null) ...[
                            const SizedBox(
                              height: 10,
                            ),

                            Text(
                              error!,

                              style:
                                  const TextStyle(
                                color:
                                    Colors.red,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Tarjeta de filtros.
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(12),

                      child: Column(
                        children: [

                          /// Filtro trabajador.
                          DropdownButtonFormField<
                              String?>(
                            initialValue:
                                filterEmployeeId,

                            isExpanded: true,

                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Filtrar por trabajador',

                              border:
                                  OutlineInputBorder(),
                            ),

                            items: [

                              /// Opción todos.
                              const DropdownMenuItem<
                                  String?>(
                                value: null,

                                child:
                                    Text('Todos'),
                              ),

                              ...empDocs.map((d) {

                                final name =
                                    (d.data()['name'] ??
                                            '')
                                        .toString();

                                return DropdownMenuItem<
                                    String?>(
                                  value: d.id,

                                  child:
                                      Text(name),
                                );
                              }),
                            ],

                            onChanged: (v) {

                              setState(() {
                                filterEmployeeId =
                                    v;
                              });
                            },
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          /// Filtros mes y año.
                          Row(
                            children: [

                              /// Filtro mes.
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                        int?>(
                                  initialValue:
                                      filterMonth,

                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Filtrar mes',

                                    border:
                                        OutlineInputBorder(),
                                  ),

                                  items: [

                                    const DropdownMenuItem<
                                        int?>(
                                      value:
                                          null,

                                      child:
                                          Text(
                                        'Todos',
                                      ),
                                    ),

                                    ...List.generate(
                                      12,
                                      (i) =>
                                          i + 1,
                                    ).map(
                                      (m) =>
                                          DropdownMenuItem<
                                              int?>(
                                        value:
                                            m,

                                        child:
                                            Text(
                                          m
                                              .toString()
                                              .padLeft(
                                                2,
                                                '0',
                                              ),
                                        ),
                                      ),
                                    ),
                                  ],

                                  onChanged:
                                      (v) {

                                    setState(() {
                                      filterMonth =
                                          v;
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(
                                width: 10,
                              ),

                              /// Filtro año.
                              Expanded(
                                child:
                                    DropdownButtonFormField<
                                        int?>(
                                  initialValue:
                                      filterYear,

                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Filtrar año',

                                    border:
                                        OutlineInputBorder(),
                                  ),

                                  items: [

                                    const DropdownMenuItem<
                                        int?>(
                                      value:
                                          null,

                                      child:
                                          Text(
                                        'Todos',
                                      ),
                                    ),

                                    ...years.map(
                                      (y) =>
                                          DropdownMenuItem<
                                              int?>(
                                        value:
                                            y,

                                        child:
                                            Text(
                                          '$y',
                                        ),
                                      ),
                                    ),
                                  ],

                                  onChanged:
                                      (v) {

                                    setState(() {
                                      filterYear =
                                          v;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Lista de nóminas.
                  Expanded(
                    child: StreamBuilder<
                        List<PayrollItem>>(
                      stream:
                          repo.streamAdminPayrolls(
                        employeeId:
                            filterEmployeeId,

                        month:
                            filterMonth,

                        year:
                            filterYear,
                      ),

                      builder: (context, snap) {

                        // Error de carga.
                        if (snap.hasError) {
                          return Center(
                            child: Text(
                              'Error: ${snap.error}',
                            ),
                          );
                        }

                        // Cargando.
                        if (!snap.hasData) {
                          return const Center(
                            child:
                                CircularProgressIndicator(),
                          );
                        }

                        final items =
                            snap.data!;

                        // Sin nóminas.
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              'No hay nóminas.',
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount:
                              items.length,

                          separatorBuilder:
                              (_, __) =>
                                  const Divider(),

                          itemBuilder:
                              (context, i) {

                            final p =
                                items[i];

                            return ListTile(

                              /// Icono PDF.
                              leading:
                                  const Icon(
                                Icons
                                    .picture_as_pdf,
                              ),

                              title: Text(
                                '${p.employeeName} - ${p.periodLabel}',

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),

                              subtitle: Text(
                                p.fileName,

                                maxLines: 2,

                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),

                              /// Menú de acciones.
                              trailing:
                                  PopupMenuButton<
                                      String>(
                                onSelected:
                                    (
                                      value,
                                    ) async {

                                  /// Abrir.
                                  if (value ==
                                      'open') {

                                    await _openUrl(
                                      p.downloadUrl,
                                    );

                                    return;
                                  }

                                  /// Descargar.
                                  if (value ==
                                      'download') {

                                    try {

                                      /// En web se abre navegador.
                                      if (kIsWeb) {

                                        await _openUrl(
                                          p.downloadUrl,
                                        );

                                        return;
                                      }

                                      /// Descarga local.
                                      final path =
                                          await _downloadToAppFolder(
                                        url:
                                            p.downloadUrl,

                                        filename:
                                            p.fileName,
                                      );

                                      /// Abre el archivo.
                                      await OpenFilex
                                          .open(
                                        path,
                                      );

                                    } catch (e) {

                                      if (!context
                                          .mounted) {

                                        return;
                                      }

                                      AppSnackbar
                                          .show(
                                        context,

                                        'Error descargando: $e',

                                        isError:
                                            true,
                                      );
                                    }
                                  }
                                },

                                itemBuilder:
                                    (_) =>
                                        const [

                                  /// Abrir.
                                  PopupMenuItem(
                                    value:
                                        'open',

                                    child:
                                        Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .open_in_new,

                                          size:
                                              18,
                                        ),

                                        SizedBox(
                                          width:
                                              8,
                                        ),

                                        Text(
                                          'Abrir',
                                        ),
                                      ],
                                    ),
                                  ),

                                  /// Descargar.
                                  PopupMenuItem(
                                    value:
                                        'download',

                                    child:
                                        Row(
                                      children: [
                                        Icon(
                                          Icons
                                              .download,

                                          size:
                                              18,
                                        ),

                                        SizedBox(
                                          width:
                                              8,
                                        ),

                                        Text(
                                          'Descargar',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              /// Apertura rápida.
                              onTap:
                                  () =>
                                      _openUrl(
                                        p.downloadUrl,
                                      ),
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