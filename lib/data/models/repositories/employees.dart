import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String dni;
  final String name;
  final String department;
  final bool active;
  final DateTime? createdAt;

  Employee({
    required this.id,
    required this.dni,
    required this.name,
    required this.department,
    required this.active,
    required this.createdAt,
  });

  factory Employee.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Employee(
      id: doc.id,
      dni: (data['dni'] ?? '') as String,
      name: (data['name'] ?? '') as String,
      department: (data['department'] ?? '') as String,
      active: (data['active'] ?? true) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'dni': dni,
        'name': name,
        'department': department,
        'active': active,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
