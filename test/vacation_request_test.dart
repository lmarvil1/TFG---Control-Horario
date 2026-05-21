import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app/data/models//repositories/vacation_request.dart';

/// Archivo de pruebas unitarias para el modelo VacationRequest.

/// Comprueba la copia de objetos, la conversión a mapa
/// y el tratamiento correcto de las fechas.
void main() {
  group('Modelo VacationRequest', () {
    /// Verifica que copyWith modifica únicamente
    /// los campos indicados y mantiene el resto igual.
    test('copyWith modifica solo los campos indicados', () {
      final request = VacationRequest(
        id: '1',
        employeeId: 'emp01',
        employeeName: 'Juan',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 5),
        days: 5,
        status: 'pending',
        workerComment: '',
        adminComment: '',
        createdAt: null,
        cancelRequestComment: '',
        cancelRequestedAt: null,
        cancelResolvedAt: null,
      );

      /// Crea una copia modificando solo el estado.
      final updated = request.copyWith(status: 'approved');

      expect(updated.status, 'approved');

      /// Comprueba que los demás campos se conservan.
      expect(updated.employeeName, 'Juan');
    });

    /// Verifica que toMap convierte correctamente
    /// las propiedades principales del modelo.
    test('toMap convierte correctamente los datos', () {
      final request = VacationRequest(
        id: '1',
        employeeId: 'emp01',
        employeeName: 'Juan',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 5),
        days: 5,
        status: 'pending',
        workerComment: 'Vacaciones',
        adminComment: '',
        createdAt: DateTime(2026, 5, 1),
        cancelRequestComment: '',
        cancelRequestedAt: null,
        cancelResolvedAt: null,
      );

      /// Convierte el modelo a mapa.
      final map = request.toMap();

      expect(map['employeeId'], 'emp01');
      expect(map['days'], 5);
      expect(map['status'], 'pending');
    });

    /// Verifica que las fechas de inicio y fin
    /// se guardan sin hora en Firestore.
    test('Las fechas se guardan sin hora', () {
      final request = VacationRequest(
        id: '1',
        employeeId: 'emp01',
        employeeName: 'Juan',
        startDate: DateTime(2026, 6, 1, 15, 30),
        endDate: DateTime(2026, 6, 5, 22, 10),
        days: 5,
        status: 'pending',
        workerComment: '',
        adminComment: '',
        createdAt: null,
        cancelRequestComment: '',
        cancelRequestedAt: null,
        cancelResolvedAt: null,
      );

      /// Convierte el modelo a mapa.
      final map = request.toMap();

      /// Recupera las fechas convertidas a Timestamp.
      final start = (map['startDate'] as Timestamp).toDate();
      final end = (map['endDate'] as Timestamp).toDate();

      expect(start.hour, 0);
      expect(end.hour, 0);
    });
  });
}