/// Clase que define los distintos roles de usuario dentro de la aplicación.
/// Define los roles en un único lugar para evitar repetir strings en el código.
/// Esto facilita cambios futuros y reduce errores.
class UserRoles {

  /// Rol con privilegios completos sobre la aplicación.
  static const String admin = 'admin';

  /// Rol correspondiente a trabajadores.
  static const String worker = 'worker';

  /// Rol de Representante Legal de los Trabajadores.
  static const String rlt = 'rlt';

  /// Rol de Representante de la Inspección de Trabajo.
  static const String inspector = 'inspector';

  /// Lista con todos los roles disponibles en el sistema.
  /// Permite iterar o validar roles de forma centralizada.
  static const List<String> all = [
    admin,
    worker,
    rlt,
    inspector,
  ];

  /// Devuelve una etiqueta legible para cada rol.
  /// Se utiliza para mostrar nombres en la interfaz de usuario en lugar de los identificadores internos.
  /// Parámetro:
  /// - role: identificador del rol (ej. 'admin', 'worker', etc.)
  /// Devuelve:
  /// - String: nombre descriptivo del rol (ej. 'Administrador', 'Trabajador', etc.)
  static String label(String role) {
    switch (role) {
      case admin:
        return 'Administrador';
      case worker:
        return 'Trabajador';
      case rlt:
        return 'Representante legal';
      case inspector:
        return 'Inspección';
      default:
        // En caso de recibir un rol no definido, se devuelve el valor original.
        return role;
    }
  }
}