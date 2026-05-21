import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app/data/models/repositories/notifications_repository.dart';

/// Archivo de pruebas unitarias para el modelo AppNotification.

/// Comprueba el estado de lectura de las notificaciones
/// según el valor del campo readAt.
void main() {
  group('Modelo AppNotification', () {
    /// Verifica que una notificación sin fecha de lectura
    /// se considera no leída.
    test('Una notificación sin readAt no está leída', () {
      const notification = AppNotification(
        id: '1',
        recipientUid: 'user01',
        title: 'Solicitud aprobada',
        body: 'Tu solicitud ha sido aprobada',
        type: 'vacation',
        createdAt: null,
        readAt: null,
        relatedId: 'vac01',
        relatedType: 'vacation_request',
        senderUid: 'admin01',
      );

      expect(notification.isRead, false);
    });

    /// Verifica que una notificación con fecha de lectura
    /// se considera leída.
    test('Una notificación con readAt está leída', () {
      final notification = AppNotification(
        id: '1',
        recipientUid: 'user01',
        title: 'Solicitud aprobada',
        body: 'Tu solicitud ha sido aprobada',
        type: 'vacation',
        createdAt: DateTime(2026, 5, 17),
        readAt: DateTime(2026, 5, 18),
        relatedId: 'vac01',
        relatedType: 'vacation_request',
        senderUid: 'admin01',
      );

      expect(notification.isRead, true);
    });
  });
}