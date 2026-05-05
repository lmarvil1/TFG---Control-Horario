import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/user_roles.dart';

import 'reset_password_page.dart';

/// Pantalla de autenticación de usuarios.
/// Permite el inicio de sesión y el registro de nuevos usuarios.
/// Gestiona la validación de formularios, la comunicación con Firebase Auth
/// y la creación del perfil básico en Firestore en caso de registro.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para los campos de entrada
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // Indica si la pantalla está en modo login o registro
  bool isLogin = true;

  // Control de estado de carga para evitar múltiples envíos
  bool loading = false;

  // Mensaje de error a mostrar en la interfaz
  String? error;

  // Controla la visibilidad del campo contraseña
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Liberación de recursos de los controladores
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  /// Gestiona el envío del formulario de autenticación.
  /// - Valida los datos introducidos
  /// - Realiza login o registro en Firebase Auth
  /// - En caso de registro, crea el documento del usuario en Firestore
  Future<void> submit() async {
    // Evita ejecuciones simultáneas
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text.trim();

      // Validación básica de campos obligatorios
      if (email.isEmpty || pass.isEmpty) {
        setState(() {
          loading = false;
          error = 'Introduce el correo y la contraseña';
        });
        return;
      }

      // Validación de contraseña en registro
      if (!isLogin && pass.length < 6) {
        setState(() {
          loading = false;
          error = 'La contraseña debe tener al menos 6 caracteres';
        });
        return;
      }

      if (isLogin) {
        // Inicio de sesión con Firebase Auth
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        // Registro de nuevo usuario
        final cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );

        // Creación del perfil básico en Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'email': email,
          'name': '',
          'role': UserRoles.worker, // Rol por defecto
          'employeeId': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      // Manejo específico de errores de autenticación
      setState(() {
        loading = false;
        error = _firebaseErrorMessage(e);
      });
      return;
    } catch (e) {
      // Manejo genérico de errores
      setState(() {
        loading = false;
        error = 'Ha ocurrido un error inesperado';
      });
      return;
    }

    // Actualiza estado solo si el widget sigue montado
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  /// Traduce los códigos de error de Firebase a mensajes comprensibles
  /// para el usuario.
  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido';
      case 'user-not-found':
        return 'No existe un usuario con ese correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos';
      case 'email-already-in-use':
        return 'Ese correo ya está registrado';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde';
      default:
        return e.message ?? 'Error de autenticación';
    }
  }

  /// Genera una decoración común para los campos de entrada,
  /// manteniendo consistencia visual en la interfaz.
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Permite adaptar la UI en pantallas pequeñas
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              // Limita el ancho máximo para mejorar la experiencia en pantallas grandes
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo de la aplicación
                  Image.asset(
                    'assets/icon2.png',
                    height: 150,
                  ),
                  const SizedBox(height: 20),

                  // Título dinámico según modo
                  Text(
                    isLogin ? 'Iniciar sesión' : 'Registrarse',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo explicativo
                  Text(
                    isLogin
                        ? 'Accede a tu cuenta'
                        : 'Crea una cuenta nueva',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Campo de email
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                    decoration: _inputDecoration(
                      label: 'Correo electrónico',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo de contraseña
                  TextField(
                    controller: passCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                    decoration: _inputDecoration(
                      label: 'Contraseña',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),

                  // Mensaje informativo en registro
                  if (!isLogin)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'La contraseña debe tener al menos 6 caracteres',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Mostrar error si existe
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  // Botón principal
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : submit,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isLogin ? 'Entrar' : 'Registrarse',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Enlace para recuperar contraseña
                  if (isLogin)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ResetPasswordPage(),
                                ),
                              );
                            },
                      child: const Text('He olvidado mi contraseña'),
                    ),

                  // Cambio entre login y registro
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin
                            ? '¿No tienes cuenta? '
                            : '¿Ya tienes cuenta? ',
                      ),
                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  isLogin = !isLogin;
                                  error = null;
                                });
                              },
                        child: Text(
                          isLogin ? 'Regístrate' : 'Inicia sesión',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}