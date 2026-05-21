import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Descarga un archivo generado en la versión web de la aplicación.

/// El archivo se crea temporalmente en memoria mediante un Blob
/// y se descarga automáticamente desde el navegador.
Future<void> downloadBytes({
  required Uint8List bytes,
  required String filename,
  required String mimeType,
}) async {

  // Crea un Blob con el contenido binario del archivo
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );

  // Genera una URL temporal asociada al Blob
  final url = web.URL.createObjectURL(blob);

  // Crea un enlace HTML temporal y ejecuta la descarga
  web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..click();

  // Libera la URL temporal creada en memoria
  web.URL.revokeObjectURL(url);
}