import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa a un empleado dentro del sistema.
/// Esta clase se utiliza para transformar los datos almacenados en Firestore
/// en un objeto Dart más fácil de manejar dentro de la aplicación.

class Employee {
  /// Identificador único del empleado.
  /// Corresponde al ID del documento en Firestore.
  final String id;

  /// Nombre del empleado.
  final String name;

  /// Departamento al que pertenece el empleado.
  final String department;

  /// Indica si el empleado está activo en el sistema.
  final bool active;

  /// Fecha de creación del registro del empleado.
  final DateTime? createdAt;

  Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.active,
    required this.createdAt,
  });

  /// Crea una instancia de Employee a partir de un documento de Firestore.
  /// Parámetro:
  /// - doc: documento obtenido desde la colección correspondiente.
  /// Devuelve:
  /// - Employee: objeto con los datos del empleado.
  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return Employee(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      department: (data['department'] ?? '') as String,
      active: (data['active'] ?? true) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convierte el objeto Employee en un mapa compatible con Firestore.
  /// Este método se utiliza al guardar o actualizar datos del empleado en la base de datos.
  Map<String, dynamic> toMap() => {
        'name': name,
        'department': department,
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
      };
}