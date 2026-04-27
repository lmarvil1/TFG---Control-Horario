class UserRoles {
  static const String admin = 'admin';
  static const String worker = 'worker';
  static const String rlt = 'rlt';
  static const String inspector = 'inspector';

  static const List<String> all = [
    admin,
    worker,
    rlt,
    inspector,
  ];

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
        return role;
    }
  }
}