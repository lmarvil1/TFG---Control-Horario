import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa un día festivo.
/// Se utiliza para almacenar y recuperar información sobre festivos
/// desde Firestore, asegurando un formato consistente de fecha.
class Holiday {
  /// Fecha del festivo (sin hora).
  final DateTime date;

  /// Nombre del festivo.
  final String name;

  /// Ámbito del festivo (nacional, autonómico, local).
  /// Por defecto se considera 'variable'.
  final String scope;

  Holiday({
    required this.date,
    required this.name,
    this.scope = 'variable',
  });

  /// Normaliza una fecha eliminando la parte de la hora.
  /// Esto evita inconsistencias al comparar fechas que provienen
  /// de distintas fuentes o formatos.
  static DateTime dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Crea una instancia de Holiday a partir de un mapa de datos.
  /// Este método gestiona distintos formatos posibles de fecha:
  /// - Timestamp (Firestore)
  /// - DateTime
  /// - String (parseable)
  factory Holiday.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final rawName = map['name'];
    final rawScope = map['scope'];

    DateTime parsedDate;

    // Conversión de la fecha según el tipo recibido
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate().toLocal();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      // Intento de parseo desde string, si falla se usa la fecha actual
      parsedDate = DateTime.tryParse('${rawDate ?? ''}')?.toLocal() ??
          DateTime.now().toLocal();
    }

    return Holiday(
      date: dateOnly(parsedDate),
      name: (rawName ?? '').toString().trim(),
      scope: (rawScope ?? 'variable').toString().trim(),
    );
  }

  /// Convierte el objeto Holiday en un mapa compatible con Firestore.
  /// La fecha se almacena como Timestamp y se normaliza previamente.
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(dateOnly(date)),
      'name': name.trim(),
      'scope': scope.trim(),
    };
  }

/// Convierte la fecha en un texto único (YYYY-MM-DD) para poder
/// comparar días fácilmente sin tener en cuenta la hora.
  String get key =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}