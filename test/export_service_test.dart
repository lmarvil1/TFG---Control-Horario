import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app/utils/export_service.dart';

/// Archivo de pruebas unitarias para la exportación de fichajes.
/// Comprueba que los nombres de archivo y el contenido CSV
/// se generan correctamente.
void main() {
  group('Exportación real de fichajes', () {
    /// Verifica que el nombre del archivo diario
    /// se construye con el empleado, la fecha y la extensión.
    test('buildFilename genera un nombre de archivo correcto', () {
      final filename = ExportService.buildFilename(
        employeeLabel: 'Juan Pérez',
        ext: 'csv',
        now: DateTime(2026, 5, 17),
      );

      expect(filename, 'Juan Pérez_2026-05-17.csv');
    });

    /// Verifica que el nombre del archivo mensual
    /// se construye con el empleado, el mes y la extensión.
    test('buildFilenameForMonth genera un nombre mensual correcto', () {
      final filename = ExportService.buildFilenameForMonth(
        employeeLabel: 'Juan Pérez',
        month: DateTime(2026, 5, 1),
        ext: 'pdf',
      );

      expect(filename, 'Juan Pérez_2026-05.pdf');
    });

    /// Verifica que se genera un CSV válido
    /// a partir de una lista de fichajes.
    test('buildCsvBytes genera CSV con fichajes', () {
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

      /// Genera los bytes del CSV.
      final bytes = ExportService.buildCsvBytes(punches);

      /// Convierte los bytes a texto para poder comprobar su contenido.
      final csv = utf8.decode(bytes);

      /// Comprueba que el CSV contiene la cabecera esperada.
      expect(csv.contains('Fecha;Hora;Tipo'), true);

      /// Comprueba que el CSV contiene la fecha del fichaje.
      expect(csv.contains('17/05/2026'), true);

      /// Comprueba que el CSV contiene la hora de entrada.
      expect(csv.contains('08:00'), true);

      /// Comprueba que el CSV contiene la hora de salida.
      expect(csv.contains('16:00'), true);
    });
  });
}