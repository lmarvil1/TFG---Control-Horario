/// Funcionamiento:
/// - En plataformas web se utiliza file_downloader_web.dart
/// - En el resto de plataformas se utiliza file_downloader_stub.dart

/// Esto permite mantener una única interfaz de descarga
/// compatible tanto con aplicaciones móviles como web.
export 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart';