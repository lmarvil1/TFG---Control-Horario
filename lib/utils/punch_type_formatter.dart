class PunchTypeFormatter {
  static String label(String? type) {
    if (type == null) return '';

    final t = type.toLowerCase().trim();

    // ✅ Soporta nuevo formato
    if (t == 'in') return 'Entrada';
    if (t == 'out') return 'Salida';

    // ✅ Compatibilidad con datos antiguos
    if (t == 'entrada') return 'Entrada';
    if (t == 'salida') return 'Salida';

    return type; // fallback
  }
}
