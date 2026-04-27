import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {
  // ✅ MUY IMPORTANTE: deja respirar a la UI (especialmente tras cerrar un BottomSheet)
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

  // Si el sistema devolvió una ruta, guardamos ahí
  if (savePath != null && savePath.trim().isNotEmpty) {
    final file = File(savePath);
    await file.writeAsBytes(bytes, flush: true);

    // Intentar abrir el archivo
    try {
      await OpenFilex.open(savePath);
    } catch (_) {}

    return;
  }

  // ✅ Fallback SI el selector no existe / el usuario cancela:
  // Guardamos en temporal y abrimos menú compartir (en iOS aparece “Guardar en Archivos”)
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

String? _extFromFilename(String filename) {
  final i = filename.lastIndexOf('.');
  if (i <= 0 || i == filename.length - 1) return null;
  return filename.substring(i + 1).toLowerCase();
}
