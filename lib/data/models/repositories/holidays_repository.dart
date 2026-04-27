import 'package:cloud_firestore/cloud_firestore.dart';

import 'holiday.dart';

class HolidaysRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('local_holidays');

  Stream<List<Holiday>> streamHolidaysForYear(int year) {

    return _col.doc('$year').snapshots().map((doc) {
 
      final fixed = _buildFixedHolidays(year);
      final variable = _readVariableHolidays(doc);

      final Map<String, Holiday> byDate = {};

      for (final h in fixed) {
        byDate[h.key] = h;
      }

      for (final h in variable) {
        byDate[h.key] = h;
      }

      final result = byDate.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      for (final h in result) {
      }

      return result;
    });
  }

  List<Holiday> _readVariableHolidays(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return <Holiday>[];
    }

    final rawItems = data['items'];

    if (rawItems is! List) {
      return <Holiday>[];
    }

    final holidays = <Holiday>[];

    for (final item in rawItems) {

      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final holiday = Holiday.fromMap(map);
        holidays.add(holiday);
      }
    }

    holidays.sort((a, b) => a.date.compareTo(b.date));
    return holidays;
  }

  List<Holiday> _buildFixedHolidays(int year) {
    final holidays = <Holiday>[
      Holiday(
        date: DateTime(year, 1, 1),
        name: 'Año Nuevo',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 1, 6),
        name: 'Epifanía del Señor',
        scope: 'national',
      ),
      Holiday(
        date: DateTime(year, 3, 19),
        name: 'San José',
        scope: 'regional',
      ),
      Holiday(
        date: DateTime(year, 5, 1),
        name: 'Fiesta del Trabajo',
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
        name: 'Fiesta Nacional de España',
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

    final Map<String, Holiday> byDate = {};
    for (final h in holidays) {
      byDate[h.key] = h;
    }

    return byDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}