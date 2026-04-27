import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/user_roles.dart';

import 'reset_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool isLogin = true;
  bool loading = false;
  String? error;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final email = emailCtrl.text.trim();
      final pass = passCtrl.text.trim();

      if (email.isEmpty || pass.isEmpty) {
        setState(() {
          loading = false;
          error = 'Introduce el correo y la contraseña';
        });
        return;
      }

      if (!isLogin && pass.length < 6) {
        setState(() {
          loading = false;
          error = 'La contraseña debe tener al menos 6 caracteres';
        });
        return;
      }

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        final cred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'email': email,
          'name': '',
          'role': UserRoles.worker,
          'employeeId': '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        loading = false;
        error = _firebaseErrorMessage(e);
      });
      return;
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Ha ocurrido un error inesperado';
      });
      return;
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido';
      case 'user-not-found':
        return 'No existe un usuario con ese correo';
      case 'wrong-password':
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon2.png',
                    height: 150,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isLogin ? 'Iniciar sesión' : 'Registrarse',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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