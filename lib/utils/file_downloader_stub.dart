import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda o comparte un archivo generado a partir de bytes.

/// Se utiliza para descargar archivos creados por la aplicación,
/// como exportaciones en PDF o CSV.
Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  // Pequeña espera para evitar conflictos con transiciones de la interfaz
  await Future.delayed(const Duration(milliseconds: 250));

  final ext = _extFromFilename(filename);

  String? savePath;

  try {
    savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Guardar archivo',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ext == null ? null : [ext],
    );
  } catch (_) {
    savePath = null;
  }

  // Si el usuario selecciona una ruta válida, el archivo se guarda en ella
  if (savePath != null && savePath.trim().isNotEmpty) {
    final file = File(savePath);

    await file.writeAsBytes(bytes, flush: true);

    try {
      await OpenFilex.open(savePath);
    } catch (_) {
      // Si no se puede abrir el archivo, se mantiene guardado igualmente.
    }

    return;
  }

  // Si no se obtiene una ruta, se crea un archivo temporal
  // y se ofrece mediante el menú de compartir del sistema.
  final tmpDir = await getTemporaryDirectory();
  final tmpPath = '${tmpDir.path}/$filename';
  final tmpFile = File(tmpPath);

  await tmpFile.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(tmpPath, mimeType: mimeType, name: filename)],
    subject: filename,
    text: 'Exportación: $filename',
  );
}

/// Obtiene la extensión de un nombre de archivo.
/// Retorna null si el nombre no contiene una extensión válida.
String? _extFromFilename(String filename) {
  final i = filename.lastIndexOf('.');

  if (i <= 0 || i == filename.length - 1) return null;

  return filename.substring(i + 1).toLowerCase();
}