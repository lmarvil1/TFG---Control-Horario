/// Clase auxiliar para convertir los tipos de fichaje
/// a un formato legible para el usuario.

class PunchTypeFormatter {

  /// Convierte el tipo de fichaje a una etiqueta legible.
  /// Retorna una cadena vacía si el valor es null.
  static String label(String? type) {
    if (type == null) return '';

    final t = type.toLowerCase().trim();

    // Compatibilidad con el formato actual
    if (t == 'in') return 'Entrada';
    if (t == 'out') return 'Salida';

    // Compatibilidad con datos almacenados anteriormente
    if (t == 'entrada') return 'Entrada';
    if (t == 'salida') return 'Salida';

    // Devuelve el valor original si no existe coincidencia
    return type;
  }
}