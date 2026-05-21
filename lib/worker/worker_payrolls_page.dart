import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/repositories/payrolls_repository.dart';
import '../utils/app_snackbar.dart';

/// Pantalla encargada de mostrar las nóminas del trabajador.

/// Permite:
/// - Consultar nóminas disponibles
/// - Filtrar por mes y año
/// - Abrir documentos 
/// - Descargar nóminas en el dispositivo
class WorkerPayrollsPage extends StatefulWidget {

  /// Identificador del empleado asociado.
  final String employeeId;

  const WorkerPayrollsPage({
    super.key,
    required this.employeeId,
  });

  @override
  State<WorkerPayrollsPage> createState() =>
      _WorkerPayrollsPageState();
}

class _WorkerPayrollsPageState
    extends State<WorkerPayrollsPage> {

  /// Repositorio encargado de la gestión de nóminas.
  final repo = PayrollsRepository();

  /// Filtro seleccionado para el mes.
  int? filterMonth;

  /// Filtro seleccionado para el año.
  int? filterYear;

  /// Lista de años disponibles para el filtro.
  final years = List<int>.generate(
    6,
    (i) => DateTime.now().year - 1 + i,
  );

  /// Abre una URL externa.
  Future<void> _openUrl(String url) async {

    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  /// Descarga un archivo en la carpeta interna de la aplicación.
  Future<String> _downloadToAppFolder({
    required String url,
    required String filename,
  }) async {

    /// Obtiene el directorio interno de la aplicación.
    final dir =
        await getApplicationDocumentsDirectory();

    /// Limpia caracteres no válidos del nombre.
    final safeName = filename.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final file =
        File('${dir.path}/$safeName');

    /// Descarga el archivo desde internet.
    await Dio().download(
      url,
      file.path,
    );

    return file.path;
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          children: [

            /// Tarjeta con filtros de búsqueda.
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(12),

                child: Row(
                  children: [

                    /// Selector de mes.
                    Expanded(
                      child:
                          DropdownButtonFormField<
                              int?>(
                        initialValue: filterMonth,

                        decoration:
                            const InputDecoration(
                          labelText: 'Mes',

                          border:
                              OutlineInputBorder(),
                        ),

                        items: [

                          /// Opción sin filtro.
                          const DropdownMenuItem<
                              int?>(
                            value: null,
                            child: Text('Todos'),
                          ),

                          /// Genera los meses del 1 al 12.
                          ...List.generate(
                            12,
                            (i) => i + 1,
                          ).map(
                            (m) =>
                                DropdownMenuItem<
                                    int?>(
                              value: m,

                              child: Text(
                                m.toString().padLeft(
                                      2,
                                      '0',
                                    ),
                              ),
                            ),
                          ),
                        ],

                        onChanged: (v) {

                          setState(
                            () => filterMonth = v,
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    /// Selector de año.
                    Expanded(
                      child:
                          DropdownButtonFormField<
                              int?>(
                        initialValue: filterYear,

                        decoration:
                            const InputDecoration(
                          labelText: 'Año',

                          border:
                              OutlineInputBorder(),
                        ),

                        items: [

                          /// Opción sin filtro.
                          const DropdownMenuItem<
                              int?>(
                            value: null,
                            child: Text('Todos'),
                          ),

                          /// Genera la lista de años.
                          ...years.map(
                            (y) =>
                                DropdownMenuItem<
                                    int?>(
                              value: y,
                              child: Text('$y'),
                            ),
                          ),
                        ],

                        onChanged: (v) {

                          setState(
                            () => filterYear = v,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            /// Contenido principal.
            Expanded(
              child:
                  StreamBuilder<List<PayrollItem>>(
                stream:
                    repo.streamEmployeePayrolls(
                  employeeId:
                      widget.employeeId,

                  month: filterMonth,
                  year: filterYear,
                ),

                builder: (context, snap) {

                  /// Error cargando datos.
                  if (snap.hasError) {

                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                      ),
                    );
                  }

                  /// Indicador de carga.
                  if (!snap.hasData) {

                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final items = snap.data!;

                  /// Mensaje cuando no existen nóminas.
                  if (items.isEmpty) {

                    return const Center(
                      child: Text(
                        'No tienes nóminas.',
                      ),
                    );
                  }

                  /// Lista de nóminas.
                  return ListView.separated(
                    itemCount: items.length,

                    separatorBuilder:
                        (_, __) =>
                            const Divider(),

                    itemBuilder: (context, i) {

                      final p = items[i];

                      return ListTile(

                        /// Icono PDF.
                        leading: const Icon(
                          Icons.picture_as_pdf,
                        ),

                        /// Periodo de la nómina.
                        title: Text(
                          p.periodLabel,

                          maxLines: 1,

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        /// Nombre del archivo.
                        subtitle: Text(
                          p.fileName,

                          maxLines: 2,

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        /// Menú de acciones.
                        trailing:
                            PopupMenuButton<String>(
                          onSelected:
                              (value) async {

                            /// Abrir documento.
                            if (value == 'open') {

                              await _openUrl(
                                p.downloadUrl,
                              );

                              return;
                            }

                            /// Descargar documento.
                            if (value ==
                                'download') {

                              try {

                                /// En web se abre directamente.
                                if (kIsWeb) {

                                  await _openUrl(
                                    p.downloadUrl,
                                  );

                                  return;
                                }

                                /// Descarga el archivo.
                                final path =
                                    await _downloadToAppFolder(
                                  url:
                                      p.downloadUrl,

                                  filename:
                                      p.fileName,
                                );

                                /// Abre el archivo descargado.
                                await OpenFilex.open(
                                  path,
                                );

                              } catch (e) {

                                if (!context.mounted) {
                                  return;
                                }

                                AppSnackbar.show(
                                  context,
                                  'Error descargando: $e',
                                  isError: true,
                                );
                              }
                            }
                          },

                          itemBuilder: (_) =>
                              const [

                            /// Opción abrir.
                            PopupMenuItem(
                              value: 'open',

                              child: Row(
                                children: [

                                  Icon(
                                    Icons.open_in_new,
                                    size: 18,
                                  ),

                                  SizedBox(width: 8),

                                  Text('Abrir'),
                                ],
                              ),
                            ),

                            /// Opción descargar.
                            PopupMenuItem(
                              value: 'download',

                              child: Row(
                                children: [

                                  Icon(
                                    Icons.download,
                                    size: 18,
                                  ),

                                  SizedBox(width: 8),

                                  Text('Descargar'),
                                ],
                              ),
                            ),
                          ],
                        ),

                        /// Apertura rápida al pulsar.
                        onTap:
                            () => _openUrl(
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
      ),
    );
  }
}