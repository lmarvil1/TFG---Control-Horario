import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/models/repositories/notifications_repository.dart';
import '../utils/app_snackbar.dart';

/// Pantalla encargada de gestionar las incidencias del trabajador.

/// Permite:
/// - Consultar incidencias enviadas
/// - Crear nuevas incidencias
/// - Revisar el estado de las incidencias
/// - Mostrar comentarios del administrador
class WorkerIncidentsPage extends StatelessWidget {

  /// Identificador del empleado asociado.
  final String employeeId;

  WorkerIncidentsPage({
    super.key,
    required this.employeeId,
  });

  /// Repositorio encargado de las notificaciones.
  final NotificationsRepository _notificationsRepo =
      NotificationsRepository();

  /// Devuelve el color correspondiente al estado.
  Color _statusColor(String status) {

    switch (status) {

      case 'approved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  /// Convierte el estado interno en una etiqueta legible.
  String _statusLabel(String status) {

    switch (status) {

      case 'approved':
        return 'Aprobada';

      case 'rejected':
        return 'Rechazada';

      default:
        return 'Pendiente';
    }
  }

  /// Convierte el tipo de incidencia en un texto legible.
  String _typeLabel(dynamic type) {

    final t = (type ?? '').toString();

    if (t == 'forgot_in') {
      return 'Entrada';
    }

    if (t == 'forgot_out') {
      return 'Salida';
    }

    return 'Incidencia';
  }

  /// Convierte un Timestamp de Firestore a DateTime.
  DateTime? _tsToDate(dynamic ts) {

    if (ts is Timestamp) {
      return ts.toDate();
    }

    return null;
  }

  /// Devuelve un valor numérico para ordenar incidencias.
  int _createdAtSortValue(
    Map<String, dynamic> data,
  ) {

    final createdAt =
        _tsToDate(data['createdAt']);

    final proposed =
        _tsToDate(data['proposedTime']);

    final d =
        createdAt ??
        proposed ??
        DateTime.fromMillisecondsSinceEpoch(0);

    return d.millisecondsSinceEpoch;
  }

  /// Formatea fecha y hora.
  String _fmt(DateTime? dt) {

    if (dt == null) {
      return '—';
    }

    final dd =
        dt.day.toString().padLeft(2, '0');

    final mm =
        dt.month.toString().padLeft(2, '0');

    final yy = dt.year.toString();

    final hh =
        dt.hour.toString().padLeft(2, '0');

    final mi =
        dt.minute.toString().padLeft(2, '0');

    return '$dd/$mm/$yy $hh:$mi';
  }

  /// Construye el indicador visual del estado.
  Widget _statusChip(String status) {

    final c = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),

        border: Border.all(color: c),

        borderRadius:
            BorderRadius.circular(999),
      ),

      child: Text(
        _statusLabel(status),

        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Obtiene los identificadores de los administradores.
  Future<List<String>> _getAdminUids() async {

    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .where(
              'role',
              isEqualTo: 'admin',
            )
            .get();

    return snap.docs.map((d) => d.id).toList();
  }

  /// Obtiene el nombre visible del usuario autenticado.
  Future<String> _getCurrentUserDisplayName() async {

    final uid =
        FirebaseAuth.instance.currentUser!.uid;

    try {

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      final data = userDoc.data();

      final name =
          (data?['name'] as String?)?.trim();

      if (name != null && name.isNotEmpty) {
        return name;
      }

    } catch (_) {}

    return 'Un trabajador';
  }

  /// Obtiene el nombre del empleado desde Firestore.
  Future<String> _loadEmployeeName(
    String employeeId,
  ) async {

    try {

      final doc =
          await FirebaseFirestore.instance
              .collection('employees')
              .doc(employeeId)
              .get();

      final data = doc.data();

      final name =
          (data?['name'] ?? '')
              .toString()
              .trim();

      return name.isEmpty
          ? 'Empleado'
          : name;

    } catch (_) {

      return 'Empleado';
    }
  }

  /// Envía notificaciones a los administradores.
  Future<void> _notifyAdmins({
    required String incidentId,
    required String workerName,
    required String incidentType,
  }) async {

    final adminUids =
        await _getAdminUids();

    if (adminUids.isEmpty) {

      debugPrint(
        'No hay admins para notificar incidencia.',
      );

      return;
    }

    final typeText =
        incidentType == 'forgot_in'
            ? 'entrada olvidada'
            : 'salida olvidada';

    for (final adminUid in adminUids) {

      await _notificationsRepo
          .createNotification(
        recipientUid: adminUid,
        title: 'Nueva incidencia',

        body:
            '$workerName ha enviado una incidencia de $typeText.',

        type: 'incident_created',
        relatedId: incidentId,
        relatedType: 'incident',
      );
    }
  }

  /// Abre el formulario de creación de incidencias.
  Future<void> _openCreateIncidentDialog(
    BuildContext context,
  ) async {

    String type = 'forgot_in';

    DateTime proposed = DateTime.now();

    bool saving = false;

    final reasonCtrl =
        TextEditingController();

    /// Permite seleccionar fecha y hora.
    Future<void> pickDateTime(
      BuildContext dialogContext,
      void Function(void Function())
          setLocalState,
    ) async {

      final d = await showDatePicker(
        context: dialogContext,
        locale: const Locale('es', 'ES'),
        initialDate: proposed,
        firstDate: DateTime(2020, 1, 1),
        lastDate: DateTime.now(),
      );

      if (d == null) return;
      if (!dialogContext.mounted) return;

      final t = await showTimePicker(
        context: dialogContext,

        initialTime:
            TimeOfDay.fromDateTime(proposed),

        builder: (context, child) {

          return MediaQuery(
            data:
                MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
            ),

            child: child!,
          );
        },
      );

      if (t == null) return;
      if (!dialogContext.mounted) return;

      setLocalState(() {

        proposed = DateTime(
          d.year,
          d.month,
          d.day,
          t.hour,
          t.minute,
        );
      });
    }

    await showDialog<void>(
      context: context,

      builder: (dialogContext) {

        return StatefulBuilder(

          builder:
              (dialogContext, setLocalState) {

            /// Envía la incidencia.
            Future<void> submit() async {

              if (saving) return;

              final reason =
                  reasonCtrl.text.trim();

              /// Verifica que exista un motivo.
              if (reason.isEmpty) {

                AppSnackbar.show(
                  context,
                  'Introduce un motivo',
                  isError: true,
                );

                return;
              }

              final now = DateTime.now();

              final selectedDateOnly =
                  DateTime(
                proposed.year,
                proposed.month,
                proposed.day,
              );

              final todayOnly = DateTime(
                now.year,
                now.month,
                now.day,
              );

              /// Evita incidencias con fecha futura.
              if (selectedDateOnly
                      .isAfter(todayOnly) ||
                  proposed.isAfter(now)) {

                AppSnackbar.show(
                  context,
                  'No puedes crear incidencias con fecha u hora futura',
                  isError: true,
                );

                return;
              }

              setLocalState(
                () => saving = true,
              );

              try {

                final uid =
                    FirebaseAuth
                        .instance
                        .currentUser!
                        .uid;

                final employeeName =
                    await _loadEmployeeName(
                  employeeId,
                );

                /// Guarda la incidencia en Firestore.
                final docRef =
                    await FirebaseFirestore
                        .instance
                        .collection(
                          'incidents',
                        )
                        .add({
                  'uid': uid,
                  'employeeId': employeeId,
                  'employeeName': employeeName,
                  'type': type,

                  'proposedTime':
                      Timestamp.fromDate(
                    proposed,
                  ),

                  'date':
                      Timestamp.fromDate(
                    DateTime(
                      proposed.year,
                      proposed.month,
                      proposed.day,
                    ),
                  ),

                  'reason': reason,
                  'status': 'pending',

                  'createdAt':
                      FieldValue.serverTimestamp(),
                });

                /// Notifica a los administradores.
                try {

                  final workerName =
                      await _getCurrentUserDisplayName();

                  await _notifyAdmins(
                    incidentId: docRef.id,
                    workerName: workerName,
                    incidentType: type,
                  );

                } catch (e) {

                  debugPrint(
                    'Error enviando notificación de incidencia al admin: $e',
                  );
                }

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.pop(dialogContext);

                if (context.mounted) {

                  AppSnackbar.show(
                    context,
                    'Incidencia enviada correctamente',
                  );
                }

              } catch (e) {

                if (!dialogContext.mounted) {
                  return;
                }

                setLocalState(
                  () => saving = false,
                );

                if (context.mounted) {

                  AppSnackbar.show(
                    context,
                    'Error enviando incidencia: $e',
                    isError: true,
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text(
                'Nueva incidencia',
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [

                    /// Selector del tipo de incidencia.
                    DropdownButtonFormField<String>(
                      initialValue: type,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Tipo de incidencia',

                        border:
                            OutlineInputBorder(),
                      ),

                      items: const [

                        DropdownMenuItem(
                          value: 'forgot_in',

                          child: Text(
                            'Olvidé fichar entrada',
                          ),
                        ),

                        DropdownMenuItem(
                          value: 'forgot_out',

                          child: Text(
                            'Olvidé fichar salida',
                          ),
                        ),
                      ],

                      onChanged: saving
                          ? null
                          : (v) {

                              if (v == null) {
                                return;
                              }

                              setLocalState(
                                () => type = v,
                              );
                            },
                    ),

                    const SizedBox(height: 12),

                    /// Selector de fecha y hora.
                    SizedBox(
                      width: double.infinity,

                      child:
                          OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () => pickDateTime(
                                  dialogContext,
                                  setLocalState,
                                ),

                        icon: const Icon(
                          Icons.calendar_month,
                        ),

                        label: Text(
                          'Fecha/hora: ${_fmt(proposed)}',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    /// Campo de texto para el motivo.
                    TextField(
                      controller: reasonCtrl,
                      enabled: !saving,
                      maxLines: 3,

                      decoration:
                          const InputDecoration(
                        labelText: 'Motivo',

                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              actions: [

                /// Botón cancelar.
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(
                            dialogContext,
                          ),

                  child: const Text(
                    'Cancelar',
                  ),
                ),

                /// Botón enviar.
                FilledButton(
                  onPressed:
                      saving ? null : submit,

                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Enviar',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    /// Libera el controlador de texto.
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final uid =
        FirebaseAuth.instance.currentUser!.uid;

    /// Stream con las incidencias del trabajador.
    final stream =
        FirebaseFirestore.instance
            .collection('incidents')
            .where('uid', isEqualTo: uid)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis incidencias',
        ),

        actions: [

          /// Botón para crear incidencias.
          IconButton(
            icon: const Icon(Icons.add),

            tooltip: 'Nueva incidencia',

            onPressed:
                () => _openCreateIncidentDialog(
                  context,
                ),
          ),
        ],
      ),

      body: SafeArea(
        child:
            StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
          stream: stream,

          builder: (context, snap) {

            if (snap.hasError) {

              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),

                  child: Text(
                    'Error cargando incidencias:\n${snap.error}',

                    textAlign:
                        TextAlign.center,
                  ),
                ),
              );
            }

            if (!snap.hasData) {

              return const Center(
                child:
                    CircularProgressIndicator(),
              );
            }

            final docs = snap.data!.docs;

            /// Mensaje cuando no existen incidencias.
            if (docs.isEmpty) {

              return const Center(
                child: Text(
                  'No has enviado incidencias',
                ),
              );
            }

            /// Ordena incidencias por fecha.
            final items =
                docs.map((d) => d.data()).toList()
                  ..sort(
                    (a, b) =>
                        _createdAtSortValue(
                          b,
                        ).compareTo(
                          _createdAtSortValue(a),
                        ),
                  );

            return ListView.builder(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 8,
              ),

              itemCount: items.length,

              itemBuilder: (context, i) {

                final data = items[i];

                final status =
                    (data['status'] ?? 'pending')
                        .toString();

                final dt =
                    _tsToDate(
                      data['proposedTime'],
                    );

                final typeLabel =
                    _typeLabel(data['type']);

                final reason =
                    (data['reason'] ?? '')
                        .toString();

                final adminComment =
                    (data['adminComment'] ?? '')
                        .toString()
                        .trim();

                return Card(
                  margin:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),

                  child: Padding(
                    padding:
                        const EdgeInsets.all(12),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        /// Cabecera de la incidencia.
                        Row(
                          children: [

                            Expanded(
                              child: Text(
                                typeLabel,

                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 16,
                                ),

                                maxLines: 1,

                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            _statusChip(status),
                          ],
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        /// Fecha y hora.
                        Text(
                          'Fecha/hora: ${_fmt(dt)}',

                          maxLines: 2,

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        /// Motivo introducido.
                        Text(
                          'Motivo: $reason',

                          maxLines: 4,

                          overflow:
                              TextOverflow.ellipsis,
                        ),

                        /// Comentario del administrador.
                        if (status ==
                                'rejected' &&
                            adminComment
                                .isNotEmpty) ...[
                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            'Comentario del administrador: $adminComment',

                            style:
                                const TextStyle(
                              color: Colors.red,
                              fontStyle:
                                  FontStyle.italic,
                            ),

                            maxLines: 4,

                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}