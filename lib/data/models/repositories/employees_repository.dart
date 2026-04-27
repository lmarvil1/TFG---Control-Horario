import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeesRepository {
  final _col = FirebaseFirestore.instance.collection('employees');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamEmployees() {
    return _col.orderBy('createdAt', descending: true).snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamEmployeeById(String id) {
    return _col.doc(id).snapshots();
  }

  Future<void> addEmployee({
    required String dni,
    required String name,
    required String department,
  }) async {
    final cleanDni = dni.trim();

    if (cleanDni.isNotEmpty) {
      final existing = await _col
          .where('dni', isEqualTo: cleanDni)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (existing.docs.isNotEmpty) {
        throw Exception('Ya existe un empleado con ese DNI');
      }
    }

    await _col.add({
      'dni': cleanDni,
      'name': name.trim(),
      'department': department.trim(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEmployee(
    String id, {
    required String dni,
    required String name,
    required String department,
    required bool active,
  }) async {
    final cleanDni = dni.trim();

    if (cleanDni.isNotEmpty) {
      final existing = await _col
          .where('dni', isEqualTo: cleanDni)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 6));

      if (existing.docs.isNotEmpty && existing.docs.first.id != id) {
        throw Exception('Ya existe otro empleado con ese DNI');
      }
    }

    await _col.doc(id).update({
      'dni': cleanDni,
      'name': name.trim(),
      'department': department.trim(),
      'active': active,
    });
  }

  Future<void> deleteEmployee(String id) async {
    await _col.doc(id).delete();
  }
}