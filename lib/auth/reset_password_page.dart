import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _email = TextEditingController();
  String? _msg;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _msg = null;
      _error = null;
    });

    try {
      final email = _email.text.trim();

      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'empty-email',
          message: 'Introduce un email',
        );
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      setState(() {
        _msg = '📩 Email enviado correctamente';
      });

    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = _friendlyError(e);
      });
    } catch (e) {
      setState(() {
        _error = 'Error inesperado';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'empty-email':
        return e.message ?? 'Introduce un email';
      case 'invalid-email':
        return 'El formato del email no es válido';
      case 'user-not-found':
        return 'No existe un usuario con ese email';
      case 'network-request-failed':
        return 'Error de red. Comprueba tu conexión';
      default:
        return 'Error: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _reset,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar email'),
              ),
            ),

            const SizedBox(height: 12),

            if (_msg != null)
              Text(
                _msg!,
                style: const TextStyle(color: Colors.green),
              ),

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }
}
