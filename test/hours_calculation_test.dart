import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app/utils/work_time.dart';

/// Archivo de pruebas unitarias para el cálculo de horas trabajadas.

/// Comprueba el tratamiento de fechas, minutos ordinarios,
/// horas extra y formato de tiempo.
void main() {
  group('Cálculo real de horas trabajadas', () {
    /// Verifica que dayKey elimina la hora
    /// y conserva únicamente año, mes y día.
    test('dayKey elimina la hora y conserva solo la fecha', () {
      final date = DateTime(2026, 5, 17, 14, 30);

      expect(WorkTime.dayKey(date), DateTime(2026, 5, 17));
    });

    /// Verifica que dayLabel convierte una fecha
    /// al formato dd/MM/yyyy.
    test('dayLabel formatea la fecha correctamente', () {
      final date = DateTime(2026, 5, 7);

      expect(WorkTime.dayLabel(date), '07/05/2026');
    });

    /// Verifica que una entrada a las 08:00
    /// y una salida a las 16:00 suman 480 minutos.
    test('minutesByDay calcula una jornada de 8 horas', () {
      /// Lista simulada de fichajes.
      final punches = [
        {
          'type': 'in',
          'at': Timestamp.fromDate(DateTime(2026, 5, 17, 8, 0)),
        },
        {
          'type': 'out',
          'at': Timestamp.fromDate(DateTime(2026, 5, 17, 16, 0)),
        },
      ];

      /// Calcula los minutos trabajados agrupados por día.
      final result = WorkTime.minutesByDay(punches);

      expect(result[DateTime(2026, 5, 17)], 480);
    });

    /// Verifica que las horas ordinarias
    /// se limitan a 480 minutos diarios.
    test('ordinaryMinutes limita la jornada ordinaria a 480 minutos', () {
      expect(WorkTime.ordinaryMinutes(600), 480);
    });

    /// Verifica que las horas extra se calculan
    /// restando la jornada ordinaria.
    test('extraMinutes calcula las horas extra', () {
      expect(WorkTime.extraMinutes(600), 120);
    });

    /// Verifica que los minutos se muestran
    /// en formato de horas y minutos.
    test('formatHM formatea minutos en horas y minutos', () {
      expect(WorkTime.formatHM(125), '2h 5m');
    });
  });
}