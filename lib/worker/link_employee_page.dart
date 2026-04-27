import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LinkEmployeePage extends StatefulWidget {
  const LinkEmployeePage({super.key});

  @override
  State<LinkEmployeePage> createState() => _LinkEmployeePageState();
}

class _LinkEmployeePageState extends State<LinkEmployeePage> {
  final dniCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    dniCtrl.dispose();
    super.dispose();
  }

  Future<void> link() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final dni = dniCtrl.text.trim().toUpperCase();
      if (dni.isEmpty) throw Exception('Introduce tu DNI');

      // 1) Buscar empleado por DNI
      final q = await FirebaseFirestore.instance
          .collection('employees')
          .where('dni', isEqualTo: dni)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        throw Exception('No existe un empleado con ese DNI. Habla con tu admin.');
      }

      final employeeDoc = q.docs.first;
      final employeeId = employeeDoc.id;

      // 2) Guardar employeeId en el perfil del usuario
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión iniciada');

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'employeeId': employeeId,
      });

      if (!mounted) return;
      Navigator.pop(context, true); // linked OK
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vincular empleado')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Introduce tu DNI para vincular tu cuenta con tu ficha de empleado.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dniCtrl,
              decoration: const InputDecoration(labelText: 'DNI'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : link,
                child: loading
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vincular'),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
