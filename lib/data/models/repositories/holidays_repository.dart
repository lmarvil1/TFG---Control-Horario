import 'package:cloud_firestore/cloud_firestore.dart';

import 'holiday.dart';

/// Repositorio encargado de gestionar los días festivos.
/// Combina festivos fijos definidos en código con festivos variables
/// almacenados en Firestore.
class HolidaysRepository {
  /// Referencia a la colección donde se almacenan los festivos variables.
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('local_holidays');

  /// Devuelve un flujo con los festivos correspondientes a un año concreto.
  /// Se obtienen los festivos variables desde Firestore y se combinan con
  /// los festivos fijos definidos localmente.
  Stream<List<Holiday>> streamHolidaysForYear(int year) {
    return _col.doc('$year').snapshots().map((doc) {
      // Festivos fijos definidos por código.
      final fixed = _buildFixedHolidays(year);

      // Festivos variables leídos desde Firestore.
      final variable = _readVariableHolidays(doc);

      // Mapa auxiliar para evitar duplicados por fecha.
      final Map<String, Holiday> byDate = {};

      // Se insertan primero los festivos fijos.
      for (final h in fixed) {
        byDate[h.key] = h;
      }

      // Los festivos variables pueden sobrescribir un festivo fijo
      // si coinciden en la misma fecha.
      for (final h in variable) {
        byDate[h.key] = h;
      }

      // Conversión a lista ordenada cronológicamente.
      final result = byDate.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return result;
    });
  }

  /// Lee los festivos variables almacenados en Firestore.
  /// El documento esperado contiene un campo 'items' con una lista de festivos.
  List<Holiday> _readVariableHolidays(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    // Si el documento no existe o no tiene datos, se devuelve una lista vacía.
    if (data == null) {
      return <Holiday>[];
    }

    final rawItems = data['items'];

    // Si el campo 'items' no es una lista, se ignora el contenido.
    if (rawItems is! List) {
      return <Holiday>[];
    }

    final holidays = <Holiday>[];

    // Conversión de cada elemento del listado a un objeto Holiday.
    for (final item in rawItems) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final holiday = Holiday.fromMap(map);
        holidays.add(holiday);
      }
    }

    // Orden cronológico de los festivos variables.
    holidays.sort((a, b) => a.date.compareTo(b.date));
    return holidays;
  }

  /// Construye la lista de festivos fijos para el año indicado.
  /// Estos festivos se definen localmente porque se repiten cada año
  /// en la misma fecha.
  List<Holiday> _buildFixedHolidays(int year) {
    final holidays = <Holiday>[
      Holiday(
        date: DateTime(year, 1, 1),
        name: 'Año Nuevo',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 1, 6),
        name: 'Día de Reyes',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 3, 19),
        name: 'San José',
        scope: 'regional',
      ),
      Holiday(
        date: DateTime(year, 5, 1),
        name: 'Día del Trabajador',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 8, 15),
        name: 'Asunción de la Virgen',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 10, 9),
        name: 'Día de la Comunitat Valenciana',
        scope: 'regional',
      ),
      Holiday(
        date: DateTime(year, 10, 12),
        name: 'Día de la Hispanidad',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 11, 1),
        name: 'Todos los Santos',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 12, 6),
        name: 'Día de la Constitución Española',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 12, 8),
        name: 'Inmaculada Concepción',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 12, 25),
        name: 'Navidad',
        scope: 'national',
      ),
    ];

    // Mapa auxiliar para asegurar que no haya festivos duplicados
    // en una misma fecha.
    final Map<String, Holiday> byDate = {};
    for (final h in holidays) {
      byDate[h.key] = h;
    }

    // Devuelve los festivos fijos ordenados por fecha.
    return byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}