import 'package:cloud_firestore/cloud_firestore.dart';

/// Repositorio encargado de la gestión de empleados en Firestore.
/// Centraliza todas las operaciones relacionadas con la colección 'employees',
/// incluyendo consultas en tiempo real, creación, actualización y eliminación.

class EmployeesRepository {

  /// Referencia a la colección 'employees' en Firestore.
  final _col = FirebaseFirestore.instance.collection('employees');

  /// Devuelve un flujo en tiempo real con la lista de empleados.
  /// Los resultados se ordenan por fecha de creación descendente,
  /// mostrando primero los más recientes.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEmployees() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  /// Devuelve un flujo en tiempo real de un empleado concreto por su ID.
  /// Parámetro:
  /// - id: identificador del documento en Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamEmployeeById(String id) {
    return _col.doc(id).snapshots();
  }

  /// Añade un nuevo empleado a la colección.
  Future<void> addEmployee({
    required String name,
    required String department,
  }) async {
    // Creación del nuevo documento en Firestore
    await _col.add({
      'name': name.trim(),
      'department': department.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza los datos de un empleado existente.
  Future<void> updateEmployee(
    String id, {
    required String name,
    required String department,
    required bool active,
  }) async {
    await _col.doc(id).update({
      'name': name.trim(),
      'department': department.trim(),
      'active': active,
    });
  }

  /// Elimina un empleado de la base de datos.
  /// Parámetro:
  /// - id: identificador del documento a eliminar
  Future<void> deleteEmployee(String id) async {
    await _col.doc(id).delete();
  }
}