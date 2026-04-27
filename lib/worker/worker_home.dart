import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../data/models/repositories/punches_repository.dart';
import '../notifications/notifications_page.dart';
import '../utils/app_snackbar.dart';
import '../utils/connectivity_service.dart';
import 'punches_history_page.dart';
import 'worker_payrolls_page.dart';
import 'worker_requests_page.dart';
import 'worker_vacations_page.dart';

class WorkerHome extends StatefulWidget {
  final bool launchedFromAdmin;

  const WorkerHome({
    super.key,
    this.launchedFromAdmin = false,
  });

  @override
  State<WorkerHome> createState() => _WorkerHomeState();
}

class _WorkerHomeState extends State<WorkerHome> {
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  String? cachedEmployeeId;
  String? _lastCachedFromFirestore;
  int _tabIndex = 0;
  bool _startupNotificationsShown = false;

  @override
  void initState() {
    super.initState();
    _loadCachedEmployeeId();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_startupNotificationsShown) {
        _startupNotificationsShown = true;
        _showStartupSnackbars();
      }
    });
  }

  Future<void> _showStartupSnackbars() async {
    try {
      final unread = await _notificationsRepo.fetchUnreadForStartup(limit: 3);
      if (!mounted || unread.isEmpty) return;

      if (unread.length > 3) {
        AppSnackbar.show(
          context,
          'Tienes ${unread.length} notificaciones nuevas',
        );
        return;
      }

      for (final n in unread) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          '${n.title}: ${n.body}',
        );
        await Future.delayed(const Duration(milliseconds: 2300));
      }
    } catch (_) {
      // No bloqueamos la pantalla si falla esto.
    }
  }

  Future<void> _loadCachedEmployeeId() async {
    final user = FirebaseAuth.instance.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('employeeId_${user.uid}');
    final cleaned = v?.trim();
    if (mounted) setState(() => cachedEmployeeId = cleaned);
  }

  Future<void> _cacheEmployeeId(String employeeId) async {
    final cleaned = employeeId.trim();
    if (cleaned.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employeeId_${user.uid}', cleaned);
    if (mounted) setState(() => cachedEmployeeId = cleaned);
  }

  AppBar _buildTopBar(String displayName) {
    return AppBar(
      automaticallyImplyLeading: !widget.launchedFromAdmin,
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        StreamBuilder<int>(
          stream: _notificationsRepo.streamUnreadCount(),
          builder: (context, snap) {
            final unreadCount = snap.data ?? 0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: 'Notificaciones',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          tooltip: widget.launchedFromAdmin
              ? 'Volver al panel admin'
              : 'Cerrar sesión',
          icon: Icon(
            widget.launchedFromAdmin
                ? Icons.switch_account
                : Icons.logout,
          ),
          onPressed: () async {
            if (widget.launchedFromAdmin) {
              Navigator.of(context).pop();
            } else {
              await FirebaseAuth.instance.signOut();
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, snap) {
        String? employeeId;

        final data = snap.data?.data();
        final name = (data?['name'] as String?)?.trim();
        final baseDisplayName =
            (name != null && name.isNotEmpty) ? name : 'Trabajador';
        final displayName = widget.launchedFromAdmin
            ? '$baseDisplayName · Vista trabajador'
            : baseDisplayName;

        if (snap.hasData) {
          final fromFirestoreRaw = data?['employeeId'] as String?;
          final fromFirestore = fromFirestoreRaw?.trim();

          if (fromFirestore != null && fromFirestore.isNotEmpty) {
            employeeId = fromFirestore;

            if (_lastCachedFromFirestore != fromFirestore) {
              _lastCachedFromFirestore = fromFirestore;
              Future.microtask(() => _cacheEmployeeId(fromFirestore));
            }
          } else {
            employeeId = cachedEmployeeId?.trim();
          }
        } else {
          employeeId = cachedEmployeeId?.trim();
        }

        if (employeeId == null || employeeId.trim().isEmpty) {
          return Scaffold(
            appBar: _buildTopBar(displayName),
            body: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tu cuenta aún no está asignada a un empleado.\n\n'
                    'Pide al administrador que te asigne.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        final empId = employeeId.trim();

        final pages = <Widget>[
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: _PunchButtons(employeeId: empId),
                    ),
                  ),
                );
              },
            ),
          ),
          PunchesHistoryPage(employeeId: empId),
          WorkerRequestsPage(employeeId: empId),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('employees')
                .doc(empId)
                .snapshots(),
            builder: (context, empSnap) {
              final empData = empSnap.data?.data();
              final employeeName =
                  ((empData?['name'] ?? displayName).toString().trim().isEmpty)
                      ? displayName
                      : (empData?['name'] ?? displayName).toString().trim();

              return WorkerVacationsPage(
                employeeId: empId,
                employeeName: employeeName,
              );
            },
          ),
          WorkerPayrollsPage(employeeId: empId),
        ];

        if (_tabIndex < 0 || _tabIndex >= pages.length) {
          _tabIndex = 0;
        }

        return Scaffold(
          appBar: _buildTopBar(displayName),
          body: IndexedStack(
            index: _tabIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) => setState(() => _tabIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fingerprint),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'Historial',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment),
                label: 'Solicitudes',
              ),
              NavigationDestination(
                icon: Icon(Icons.beach_access),
                label: 'Vacaciones',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long),
                label: 'Nóminas',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PunchButtons extends StatefulWidget {
  final String employeeId;

  const _PunchButtons({required this.employeeId});

  @override
  State<_PunchButtons> createState() => _PunchButtonsState();
}

class _PunchButtonsState extends State<_PunchButtons> {
  final repo = PunchesRepository();

  bool busy = false;
  String? error;
  String? lastType;

  String? infoMessage;
  bool infoIsError = false;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _loadLast();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLast() async {
    try {
      final t = await repo.getLastType(widget.employeeId);
      if (mounted) setState(() => lastType = t);
    } catch (_) {}
  }

  void _showTemporaryMessage(String msg, {bool isError = false}) {
    _messageTimer?.cancel();
    setState(() {
      infoMessage = msg;
      infoIsError = isError;
    });

    _messageTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => infoMessage = null);
    });
  }

  Future<void> _punch(String type) async {
    if (busy) return;

    final prev = lastType;

    setState(() {
      busy = true;
      error = null;
      lastType = type;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => busy = false);
    });

    final online = await ConnectivityService.hasInternet();

    _showTemporaryMessage(
      online
          ? 'Fichaje guardado'
          : 'Fichaje guardado sin conexión. Se sincronizará cuando vuelva internet.',
    );

    repo.addPunch(employeeId: widget.employeeId, type: type).catchError((e) {
      if (!mounted) return Future.value();

      setState(() {
        lastType = prev;
        error = e.toString();
      });

      _showTemporaryMessage('Error guardando fichaje', isError: true);
      return Future.value();
    });
  }

  String _lastLabel() {
    if (lastType == 'in') return 'ENTRADA';
    if (lastType == 'out') return 'SALIDA';
    return 'SIN FICHAJES';
  }

  IconData _lastIcon() {
    if (lastType == 'in') return Icons.login_rounded;
    if (lastType == 'out') return Icons.logout_rounded;
    return Icons.fingerprint_rounded;
  }

  Color _lastColor() {
    if (lastType == 'in') return const Color(0xFF6FAF73);
    if (lastType == 'out') return const Color(0xFFD97A7A);
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final entryColor = const Color(0xFF7BC47F);
    final exitColor = const Color(0xFFE58A8A);

    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 24),
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
          decoration: BoxDecoration(
            color: _lastColor().withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _lastColor().withOpacity(0.35),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'ÚLTIMO FICHAJE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Icon(
                _lastIcon(),
                size: 42,
                color: _lastColor(),
              ),
              const SizedBox(height: 10),
              Text(
                _lastLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _lastColor(),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 34),
        SizedBox(
          width: double.infinity,
          height: 90,
          child: ElevatedButton.icon(
            style: buttonStyle.copyWith(
              backgroundColor: MaterialStateProperty.all(entryColor),
              foregroundColor: MaterialStateProperty.all(Colors.white),
            ),
            icon: const Icon(Icons.login, size: 34),
            label: const Text('ENTRADA'),
            onPressed: !busy ? () => _punch('in') : null,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 90,
          child: ElevatedButton.icon(
            style: buttonStyle.copyWith(
              backgroundColor: MaterialStateProperty.all(exitColor),
              foregroundColor: MaterialStateProperty.all(Colors.white),
            ),
            icon: const Icon(Icons.logout, size: 34),
            label: const Text('SALIDA'),
            onPressed: !busy ? () => _punch('out') : null,
          ),
        ),
        if (infoMessage != null) ...[
          const SizedBox(height: 18),
          Text(
            infoMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: infoIsError
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }
}