import 'package:flutter_test/flutter_test.dart';
import 'package:tfg_app/core/user_roles.dart';

/// Archivo de pruebas unitarias para los roles de usuario.

/// Comprueba la existencia de roles, su inclusión
/// en la lista general y sus etiquetas legibles.
void main() {
  group('Roles de usuario', () {
    /// Verifica que el rol administrador
    /// existe correctamente.
    test('El rol admin existe correctamente', () {
      expect(UserRoles.admin, 'admin');
    });

    /// Verifica que el rol trabajador
    /// existe correctamente.
    test('El rol worker existe correctamente', () {
      expect(UserRoles.worker, 'worker');
    });

    /// Verifica que la lista de roles
    /// contiene el rol inspector.
    test('La lista de roles contiene inspector', () {
      expect(
        UserRoles.all.contains(UserRoles.inspector),
        true,
      );
    });

    /// Verifica que la etiqueta del rol administrador
    /// se convierte correctamente a texto legible.
    test('La etiqueta del administrador es correcta', () {
      expect(
        UserRoles.label(UserRoles.admin),
        'Administrador',
      );
    });

    /// Verifica que la etiqueta del rol trabajador
    /// se convierte correctamente a texto legible.
    test('La etiqueta del trabajador es correcta', () {
      expect(
        UserRoles.label(UserRoles.worker),
        'Trabajador',
      );
    });

    /// Verifica que la etiqueta del rol inspector
    /// se convierte correctamente a texto legible.
    test('La etiqueta del inspector es correcta', () {
      expect(
        UserRoles.label(UserRoles.inspector),
        'Inspección',
      );
    });

    /// Verifica que un rol desconocido
    /// devuelve el mismo valor recibido.
    test('Un rol desconocido devuelve el valor original', () {
      expect(
        UserRoles.label('otro'),
        'otro',
      );
    });
  });
}