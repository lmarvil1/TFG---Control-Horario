import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Pantalla para la recuperación de contraseña.
/// Permite al usuario solicitar un correo de restablecimiento de contraseña
/// utilizando Firebase Authentication. Gestiona la validación del email,
/// el estado de carga y la presentación de mensajes de éxito o error.

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Controlador del campo de email
  final _email = TextEditingController();

  // Mensaje de éxito mostrado al usuario
  String? _msg;

  // Mensaje de error mostrado al usuario
  String? _error;

  // Indica si se está procesando la solicitud
  bool _loading = false;

  @override
  void dispose() {
    // Liberación del controlador para evitar fugas de memoria
    _email.dispose();
    super.dispose();
  }

  /// Envía la solicitud de restablecimiento de contraseña.
  /// - Valida que el email no esté vacío
  /// - Llama a Firebase Auth para enviar el correo
  /// - Gestiona mensajes de éxito y error
  Future<void> _reset() async {
    setState(() {
      _loading = true;
      _msg = null;
      _error = null;
    });

    try {
      final email = _email.text.trim();

      // Validación del campo email
      if (email.isEmpty) {
        throw FirebaseAuthException(
          code: 'empty-email',
          message: 'Introduce un email',
        );
      }

      // Envío del email de recuperación mediante Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      // Mensaje de confirmación al usuario
      setState(() {
        _msg = 'Email enviado correctamente';
      });

    } on FirebaseAuthException catch (e) {
      // Manejo de errores específicos de Firebase
      setState(() {
        _error = _friendlyError(e);
      });
    } catch (e) {
      // Manejo genérico de errores no controlados
      setState(() {
        _error = 'Error inesperado';
      });
    } finally {
      // Se asegura de actualizar el estado solo si el widget sigue activo
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Traduce los códigos de error de Firebase a mensajes comprensibles.
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
      // Barra superior con título descriptivo
      appBar: AppBar(title: const Text('Recuperar contraseña')),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Campo de entrada de email
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),

            const SizedBox(height: 16),

            // Botón para enviar la solicitud
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

            // Mensaje de éxito
            if (_msg != null)
              Text(
                _msg!,
                style: const TextStyle(color: Colors.green),
              ),

            // Mensaje de error
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