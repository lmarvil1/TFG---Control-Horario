import 'dart:async';
import 'package:flutter/material.dart';

class AppSnackbar {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final color = isError
        ? const Color(0xFFD96C6C) // rojo suave
        : const Color(0xFF5C7FA3); // azul grisáceo suave

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

class _TopSnackbarWidget extends StatefulWidget {
  final String message;
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
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
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
                      color: Colors.black.withOpacity(0.12),
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