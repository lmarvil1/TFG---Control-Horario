import 'dart:async';
import 'package:flutter/material.dart';

/// Clase auxiliar para mostrar mensajes personalizados
/// en la parte superior de la pantalla.

class AppSnackbar {
  /// Referencia al mensaje que se está mostrando actualmente.
  static OverlayEntry? _currentEntry;

  /// Temporizador encargado de cerrar automáticamente el mensaje.
  static Timer? _timer;

  /// Muestra un mensaje en la parte superior de la pantalla.
  /// Si ya existe otro mensaje visible, se elimina antes de mostrar el nuevo.
  
  /// Parámetros:
  /// - context: contexto actual de la interfaz
  /// - message: texto que se mostrará al usuario
  /// - isError: indica si el mensaje corresponde a un error
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);

    final color = isError
        ? const Color(0xFFD96C6C)
        : const Color(0xFF5C7FA3);

    final entry = OverlayEntry(
      builder: (context) => _TopSnackbarWidget(
        message: message,
        backgroundColor: color,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(seconds: 3), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

/// Widget interno encargado de representar visualmente el mensaje superior.
class _TopSnackbarWidget extends StatefulWidget {
  /// Texto mostrado dentro del mensaje.
  final String message;

  /// Color de fondo del mensaje.
  final Color backgroundColor;

  const _TopSnackbarWidget({
    required this.message,
    required this.backgroundColor,
  });

  @override
  State<_TopSnackbarWidget> createState() => _TopSnackbarWidgetState();
}

class _TopSnackbarWidgetState extends State<_TopSnackbarWidget>
    with SingleTickerProviderStateMixin {
  /// Controlador de la animación de entrada.
  late final AnimationController _controller;

  /// Animación de desplazamiento vertical.
  late final Animation<Offset> _offsetAnimation;

  /// Animación de opacidad.
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: true,
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: SlideTransition(
              position: _offsetAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}