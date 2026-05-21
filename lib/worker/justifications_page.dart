import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/repositories/justifications_repository.dart';
import '../utils/app_snackbar.dart';

/// Pantalla encargada de gestionar los justificantes del trabajador.

/// Permite:
/// - Seleccionar una fecha
/// - Adjuntar un archivo
/// - Introducir un motivo
/// - Subir justificantes a Firebase
/// - Consultar justificantes previamente subidos
class JustificationsPage extends StatefulWidget {

  /// Identificador del empleado asociado.
  final String employeeId;

  /// Indica si debe mostrarse la AppBar.
  
  /// Cuando esta pantalla se utiliza dentro de WorkerHome,
  /// puede desactivarse para evitar una doble barra superior.
  final bool showAppBar;

  const JustificationsPage({
    super.key,
    required this.employeeId,
    this.showAppBar = true,
  });

  @override
  State<JustificationsPage> createState() =>
      _JustificationsPageState();
}

class _JustificationsPageState
    extends State<JustificationsPage> {

  /// Repositorio encargado de la gestión de justificantes.
  final repo = JustificationsRepository();

  /// Controlador del campo de texto del motivo.
  final reasonCtrl = TextEditingController();

  /// Formateador de fechas.
  final df = DateFormat('dd/MM/yyyy');

  /// Fecha seleccionada para el justificante.
  DateTime selectedDate = DateTime.now();

  /// Archivo seleccionado por el usuario.
  PlatformFile? picked;

  /// Indica si el justificante se está subiendo.
  bool uploading = false;

  /// Mensaje de error mostrado en pantalla.
  String? error;

  @override
  void dispose() {

    /// Libera recursos del controlador de texto.
    reasonCtrl.dispose();

    super.dispose();
  }

  /// Muestra un selector de fecha.
  Future<void> _pickDate() async {

    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (d != null) {
      setState(() => selectedDate = d);
    }
  }

  /// Permite seleccionar un archivo desde el dispositivo.
  
  /// Solo se aceptan:
  /// - PDF
  /// - PNG
  /// - JPG
  /// - JPEG
  Future<void> _pickFile() async {

    setState(() {
      error = null;
      picked = null;
    });

    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: [
        'pdf',
        'png',
        'jpg',
        'jpeg',
      ],
    );

    if (res == null || res.files.isEmpty) {
      return;
    }

    final f = res.files.first;

    /// Verifica que los bytes del archivo estén disponibles.
    if (f.bytes == null) {

      setState(() {
        error =
            'No se pudieron leer los bytes del archivo.';
      });

      return;
    }

    setState(() => picked = f);
  }

  /// Determina automáticamente el tipo MIME del archivo.
  String _guessContentType(String filename) {

    final lower = filename.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    return 'application/octet-stream';
  }

  /// Sube el justificante al repositorio.
  Future<void> _upload() async {

    /// Oculta el teclado.
    FocusScope.of(context).unfocus();

    final user =
        FirebaseAuth.instance.currentUser!;

    final reason =
        reasonCtrl.text.trim();

    /// Verifica que exista un archivo seleccionado.
    if (picked == null) {

      setState(() {
        error =
            'Selecciona un archivo (PDF o imagen).';
      });

      return;
    }

    /// Verifica que exista un motivo.
    if (reason.isEmpty) {

      setState(() {
        error =
            'Escribe el motivo del justificante.';
      });

      return;
    }

    setState(() {
      uploading = true;
      error = null;
    });

    try {

      /// Subida del justificante.
      await repo.uploadJustification(
        uid: user.uid,
        employeeId: widget.employeeId,
        filename: picked!.name,
        bytes: picked!.bytes!,
        contentType:
            _guessContentType(picked!.name),
        reason: reason,
        date: selectedDate,
      );

      if (!mounted) return;

      /// Limpieza de formulario tras la subida.
      setState(() {
        picked = null;
        reasonCtrl.clear();
      });

      /// Muestra mensaje de éxito.
      AppSnackbar.show(
        context,
        'Justificante subido correctamente',
      );

    } catch (e) {

      if (!mounted) return;

      setState(() {
        error = e.toString();
      });

    } finally {

      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  /// Construye el contenido principal de la pantalla.
  Widget _body(BuildContext context) {

    final user =
        FirebaseAuth.instance.currentUser!;

    /// Espacio ocupado por el teclado virtual.
    final bottomInset =
        MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: CustomScrollView(
        slivers: [

          /// Formulario de subida de justificantes.
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + bottomInset,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,

                children: [

                  /// Campo para introducir el motivo.
                  TextField(
                    controller: reasonCtrl,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Motivo (ej: Cita médica, baja, retraso...)',

                      border:
                          OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// Botones de selección.
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,

                    children: [

                      /// Selector de fecha.
                      SizedBox(
                        width: double.infinity,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              uploading
                                  ? null
                                  : _pickDate,

                          icon: const Icon(
                            Icons.date_range,
                          ),

                          label: Text(
                            'Fecha: ${df.format(selectedDate)}',
                          ),
                        ),
                      ),

                      /// Selector de archivo.
                      SizedBox(
                        width: double.infinity,

                        child:
                            ElevatedButton.icon(
                          onPressed:
                              uploading
                                  ? null
                                  : _pickFile,

                          icon: const Icon(
                            Icons.attach_file,
                          ),

                          label: const Text(
                            'Elegir archivo',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  /// Información del archivo seleccionado.
                  if (picked != null)
                    Text(
                      'Archivo: ${picked!.name} (${(picked!.size / 1024).toStringAsFixed(1)} KB)',

                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                  const SizedBox(height: 10),

                  /// Botón de subida.
                  SizedBox(
                    width: double.infinity,

                    child: ElevatedButton(
                      onPressed:
                          uploading
                              ? null
                              : _upload,

                      child: uploading
                          ? const SizedBox(
                              height: 18,
                              width: 18,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Subir justificante',
                            ),
                    ),
                  ),

                  /// Mensaje de error.
                  if (error != null) ...[
                    const SizedBox(height: 10),

                    Text(
                      error!,
                      style: const TextStyle(
                        color: Colors.red,
                      ),
                    ),
                  ],

                  const Divider(height: 30),

                  /// Título de la lista.
                  const Text(
                    'Mis justificantes',

                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          /// Listado de justificantes subidos.
          SliverFillRemaining(
            hasScrollBody: true,

            child:
                StreamBuilder<
                    QuerySnapshot<
                        Map<String, dynamic>>>(
              stream: repo.streamMine(user.uid),

              builder: (context, snap) {

                if (snap.hasError) {

                  return Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(12),

                      child: Text(
                        'Error cargando justificantes:\n${snap.error}',

                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {

                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                final docs =
                    snap.data!.docs;

                /// Mensaje cuando no existen justificantes.
                if (docs.isEmpty) {

                  return const Center(
                    child: Text(
                      'No has subido justificantes.',
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                  ),

                  itemCount: docs.length,

                  separatorBuilder:
                      (_, __) =>
                          const Divider(),

                  itemBuilder: (context, i) {

                    final data =
                        docs[i].data();

                    final reason =
                        (data['reason'] ?? '')
                            .toString();

                    final filename =
                        (data['filename'] ?? '')
                            .toString();

                    final dateTs =
                        data['date']
                            as Timestamp?;

                    final date =
                        dateTs?.toDate();

                    /// Detecta si el archivo es PDF.
                    final isPdf =
                        (data['contentType'] ?? '')
                            .toString()
                            .contains('pdf');

                    return ListTile(

                      leading: Icon(
                        isPdf
                            ? Icons.picture_as_pdf
                            : Icons.image,
                      ),

                      title: Text(
                        reason.isEmpty
                            ? filename
                            : reason,

                        maxLines: 1,

                        overflow:
                            TextOverflow.ellipsis,
                      ),

                      subtitle: Text(
                        '${date != null ? df.format(date) : '-'} · $filename',

                        maxLines: 2,

                        overflow:
                            TextOverflow.ellipsis,
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
  }

  @override
  Widget build(BuildContext context) {

    /// Si no se necesita AppBar, solo se muestra el cuerpo.
    if (!widget.showAppBar) {
      return _body(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Justificantes',
        ),
      ),

      body: _body(context),
    );
  }
}