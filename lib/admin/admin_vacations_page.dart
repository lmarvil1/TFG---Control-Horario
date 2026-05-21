import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/repositories/employees.dart';
import '../data/models/repositories/employees_repository.dart';
import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/holidays_repository.dart';
import '../data/models/repositories/vacation_request.dart';
import '../data/models/repositories/vacations_repository.dart';
import '../utils/app_snackbar.dart';
import 'vacation_calendar_tab.dart';
import 'vacation_quadrant_tab.dart';

/// Pantalla principal de gestión de vacaciones.

/// Permite:
/// - Gestionar solicitudes.
/// - Aprobar o rechazar vacaciones.
/// - Gestionar cancelaciones.
/// - Consultar calendario.
/// - Visualizar cuadrante mensual.
class AdminVacationsPage extends StatefulWidget {

  /// Indica si la pantalla se muestra
  /// en modo solo lectura.
  final bool readOnly;

  const AdminVacationsPage({
    super.key,
    this.readOnly = false,
  });

  @override
  State<AdminVacationsPage> createState() =>
      _AdminVacationsPageState();
}

class _AdminVacationsPageState
    extends State<AdminVacationsPage>
    with SingleTickerProviderStateMixin {

  /// Repositorio de vacaciones.
  final repo = VacationsRepository();

  /// Repositorio de empleados.
  final employeesRepo =
      EmployeesRepository();

  /// Repositorio de festivos.
  final holidaysRepo =
      HolidaysRepository();

  /// Formato de fecha utilizado.
  final df =
      DateFormat('dd/MM/yyyy', 'es_ES');

  /// Controlador de pestañas.
  late TabController _tabController;

  /// Mes visible actualmente.
  DateTime visibleMonth =
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      );

  /// Día seleccionado en el calendario.
  DateTime selectedDay =
      DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  /// Filtro actual de solicitudes.
  String requestFilter = 'all';

  @override
  void initState() {
    super.initState();

    // Inicializa el controlador de pestañas.
    _tabController = TabController(
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {

    // Libera el controlador.
    _tabController.dispose();

    super.dispose();
  }

  /// Devuelve el color asociado
  /// a un estado de solicitud.
  Color _statusColor(String status) {
    switch (status) {

      case 'approved':
        return Colors.green;

      case 'rejected':
        return Colors.red;

      case 'cancel_requested':
        return Colors.deepOrange;

      case 'cancelled':
        return Colors.grey;

      default:
        return Colors.orange;
    }
  }

  /// Convierte el estado interno
  /// a texto legible.
  String _statusLabel(String status) {
    switch (status) {

      case 'approved':
        return 'Aprobada';

      case 'rejected':
        return 'Rechazada';

      case 'cancel_requested':
        return 'Cancelación solicitada';

      case 'cancelled':
        return 'Cancelada';

      default:
        return 'Pendiente';
    }
  }

  /// Devuelve el icono asociado
  /// al estado de la solicitud.
  IconData _statusIcon(String status) {
    switch (status) {

      case 'approved':
        return Icons.check_circle_outline;

      case 'rejected':
        return Icons.cancel_outlined;

      case 'cancel_requested':
        return Icons.undo_rounded;

      case 'cancelled':
        return Icons.remove_circle_outline;

      default:
        return Icons.hourglass_top_rounded;
    }
  }

  /// Cambia el mes visible
  /// del calendario y cuadrante.
  void _changeVisibleMonth(int delta) {

    setState(() {

      final newMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + delta,
        1,
      );

      visibleMonth = newMonth;

      selectedDay = DateTime(
        newMonth.year,
        newMonth.month,
        1,
      );
    });
  }

  /// Aprueba una solicitud de vacaciones.
  Future<void> _approve(
    VacationRequest request,
  ) async {

    try {

      await repo.approveRequest(
        request.id,
      );

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Solicitud aprobada',
      );

    } catch (e) {

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Error al aprobar la solicitud: $e',
        isError: true,
      );
    }
  }

  /// Muestra el diálogo para rechazar
  /// una solicitud de vacaciones.
  Future<void> _rejectDialog(
    VacationRequest request,
  ) async {

    /// Comentario introducido por el administrador.
    String adminComment = '';

    final ok =
        await showDialog<bool>(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {

        final mq =
            MediaQuery.of(dialogContext);

        final isSmall =
            mq.size.width < 380;

        return AlertDialog(

          title:
              const Text(
            'Rechazar solicitud',
          ),

          content:
              SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    mq.size.width * 0.85,
              ),

              child: Column(
                mainAxisSize:
                    MainAxisSize.min,

                children: [

                  /// Información de la solicitud.
                  Text(
                    '${request.employeeName}\n'
                    '${df.format(request.startDate)} - ${df.format(request.endDate)}',

                    textAlign:
                        TextAlign.center,

                    style: TextStyle(
                      fontSize:
                          isSmall ? 13 : 14,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  /// Campo de comentario.
                  TextFormField(
                    initialValue: '',
                    maxLines: 3,

                    onChanged:
                        (value) =>
                            adminComment =
                                value,

                    decoration:
                        const InputDecoration(
                      labelText:
                          'Motivo del rechazo',

                      border:
                          OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [

            /// Botón cancelar.
            TextButton(
              onPressed: () {

                FocusScope.of(
                  dialogContext,
                ).unfocus();

                Navigator.of(
                  dialogContext,
                ).pop(false);
              },

              child:
                  const Text(
                'Cancelar',
              ),
            ),

            /// Botón confirmar rechazo.
            FilledButton(
              onPressed: () {

                FocusScope.of(
                  dialogContext,
                ).unfocus();

                Navigator.of(
                  dialogContext,
                ).pop(true);
              },

              child:
                  const Text(
                'Confirmar',
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    try {

      await repo.rejectRequest(
        request.id,
        adminComment.trim(),
      );

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Solicitud rechazada',
      );

    } catch (e) {

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Error al rechazar la solicitud: $e',
        isError: true,
      );
    }
  }

  /// Muestra el diálogo para aprobar
  /// una cancelación de vacaciones.
  Future<void> _approveCancellationDialog(
    VacationRequest request,
  ) async {

    final commentCtrl =
        TextEditingController();

    final ok =
        await showDialog<bool>(
      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title:
              const Text(
            'Aceptar cancelación',
          ),

          content:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Text(
                  'Se cancelarán las vacaciones de ${request.employeeName}.',
                ),

                const SizedBox(
                  height: 12,
                ),

                /// Comentario opcional.
                TextField(
                  controller:
                      commentCtrl,

                  maxLines: 3,

                  decoration:
                      const InputDecoration(
                    labelText:
                        'Comentario opcional',

                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          actions: [

            /// Botón volver.
            TextButton(
              onPressed:
                  () => Navigator.pop(
                dialogContext,
                false,
              ),

              child:
                  const Text(
                'Volver',
              ),
            ),

            /// Botón aceptar.
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                dialogContext,
                true,
              ),

              child:
                  const Text(
                'Aceptar',
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) {

      commentCtrl.dispose();
      return;
    }

    try {

      await repo.approveCancellation(
        request.id,
      );

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Cancelación aprobada',
      );

    } catch (e) {

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Error al aprobar la cancelación: $e',
        isError: true,
      );

    } finally {

      // Libera el controlador.
      commentCtrl.dispose();
    }
  }

  /// Muestra el diálogo para denegar
  /// una cancelación de vacaciones.
  Future<void> _denyCancellationDialog(
    VacationRequest request,
  ) async {

    final commentCtrl =
        TextEditingController();

    final ok =
        await showDialog<bool>(
      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          title:
              const Text(
            'Denegar cancelación',
          ),

          content:
              SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,

              children: [

                Text(
                  'Las vacaciones seguirán aprobadas para ${request.employeeName}.',
                ),

                const SizedBox(
                  height: 12,
                ),

                /// Campo motivo opcional.
                TextField(
                  controller:
                      commentCtrl,

                  maxLines: 3,

                  decoration:
                      const InputDecoration(
                    labelText:
                        'Motivo opcional',

                    border:
                        OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),

          actions: [

            /// Botón volver.
            TextButton(
              onPressed:
                  () => Navigator.pop(
                dialogContext,
                false,
              ),

              child:
                  const Text(
                'Volver',
              ),
            ),

            /// Botón denegar.
            FilledButton(
              onPressed:
                  () => Navigator.pop(
                dialogContext,
                true,
              ),

              child:
                  const Text(
                'Denegar',
              ),
            ),
          ],
        );
      },
    );

    if (ok != true) {

      commentCtrl.dispose();
      return;
    }

    try {

      await repo.denyCancellation(
        request.id,
        commentCtrl.text,
      );

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Cancelación denegada',
      );

    } catch (e) {

      if (!mounted) return;

      AppSnackbar.show(
        context,
        'Error al denegar la cancelación: $e',
        isError: true,
      );

    } finally {

      // Libera el controlador.
      commentCtrl.dispose();
    }
  }

  /// Widget visual del estado.
  Widget _statusChip(String status) {

    final c =
        _statusColor(status);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color:
            c.withValues(alpha: 0.12),

        border:
            Border.all(color: c),

        borderRadius:
            BorderRadius.circular(999),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [

          /// Icono del estado.
          Icon(
            _statusIcon(status),
            size: 16,
            color: c,
          ),

          const SizedBox(width: 6),

          /// Texto del estado.
          Flexible(
            child: Text(
              _statusLabel(status),

              overflow:
                  TextOverflow.ellipsis,

              style: TextStyle(
                color: c,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chips de filtrado.
  Widget _filterChips() {

    Widget chip(
      String label,
      String value,
    ) {

      final selected =
          requestFilter == value;

      return ChoiceChip(
        label: Text(label),

        selected: selected,

        onSelected: (_) {

          setState(() {
            requestFilter = value;
          });
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,

      children: [
        chip('Todas', 'all'),
        chip('Pendientes', 'pending'),
        chip('Aprobadas', 'approved'),
        chip('Rechazadas', 'rejected'),
        chip(
          'Cancelación solicitada',
          'cancel_requested',
        ),
        chip(
          'Canceladas',
          'cancelled',
        ),
      ],
    );
  }

  /// Tarjeta visual de solicitud.
  Widget _requestCard(
    VacationRequest r,
  ) {

    final width =
        MediaQuery.of(context)
            .size
            .width;

    final isSmall =
        width < 380;

    /// Puede revisarse.
    final canReview =
        !widget.readOnly &&
            r.status == 'pending';

    /// Puede resolverse cancelación.
    final canResolveCancellation =
        !widget.readOnly &&
            r.status ==
                'cancel_requested';

    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          isSmall ? 10 : 12,
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            /// Cabecera.
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                const Icon(
                  Icons
                      .beach_access_rounded,
                ),

                const SizedBox(
                  width: 8,
                ),

                /// Nombre trabajador.
                Expanded(
                  child: Text(
                    r.employeeName,

                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,

                      fontSize:
                          isSmall
                              ? 15
                              : 16,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                Flexible(
                  child:
                      _statusChip(
                    r.status,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            /// Periodo solicitado.
            Text(
              'Periodo: ${df.format(r.startDate)} - ${df.format(r.endDate)}',

              style: TextStyle(
                fontSize:
                    isSmall
                        ? 13
                        : 14,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            /// Duración.
            Text(
              'Duración: ${r.days} día(s)',

              style: TextStyle(
                fontSize:
                    isSmall
                        ? 13
                        : 14,
              ),
            ),

            /// Fecha de solicitud.
            if (r.createdAt != null) ...[
              const SizedBox(
                height: 4,
              ),

              Text(
                'Solicitada: ${df.format(r.createdAt!)}',

                style: TextStyle(
                  fontSize:
                      isSmall
                          ? 13
                          : 14,
                ),
              ),
            ],

            /// Comentario trabajador.
            if (r.workerComment
                .trim()
                .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),

              Text(
                'Comentario trabajador: ${r.workerComment}',

                style: TextStyle(
                  fontSize:
                      isSmall
                          ? 13
                          : 14,
                ),
              ),
            ],

            /// Comentario rechazo.
            if (r.status ==
                    'rejected' &&
                r.adminComment
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),

              Text(
                'Motivo rechazo: ${r.adminComment}',

                style: TextStyle(
                  color: Colors.red,
                  fontWeight:
                      FontWeight.w600,

                  fontSize:
                      isSmall
                          ? 13
                          : 14,
                ),
              ),
            ],

            /// Información cancelación.
            if (r.status ==
                'cancel_requested') ...[
              const SizedBox(
                height: 8,
              ),

              Text(
                'El trabajador ha solicitado cancelar estas vacaciones.',

                style: TextStyle(
                  color:
                      Colors.orange
                          .shade800,

                  fontWeight:
                      FontWeight.w600,

                  fontSize:
                      isSmall
                          ? 13
                          : 14,
                ),
              ),

              if (r.cancelRequestComment
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Motivo trabajador: ${r.cancelRequestComment}',

                  style: TextStyle(
                    fontSize:
                        isSmall
                            ? 13
                            : 14,
                  ),
                ),
              ],
            ],

            /// Cancelación denegada.
            if (r.status ==
                    'approved' &&
                r.cancelResolvedAt !=
                    null &&
                r.adminComment
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(
                height: 8,
              ),

              Text(
                'Cancelación denegada: ${r.adminComment}',

                style: TextStyle(
                  color:
                      Colors.green
                          .shade700,

                  fontWeight:
                      FontWeight.w600,

                  fontSize:
                      isSmall
                          ? 13
                          : 14,
                ),
              ),
            ],

            /// Botones aprobar/rechazar.
            if (canReview) ...[
              const SizedBox(
                height: 10,
              ),

              Row(
                children: [

                  Expanded(
                    child:
                        OutlinedButton.icon(
                      icon:
                          const Icon(
                        Icons.close,
                      ),

                      onPressed:
                          () =>
                              _rejectDialog(
                        r,
                      ),

                      label:
                          const Text(
                        'Rechazar',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        ElevatedButton.icon(
                      icon:
                          const Icon(
                        Icons.check,
                      ),

                      onPressed:
                          () =>
                              _approve(
                        r,
                      ),

                      label:
                          const Text(
                        'Aprobar',
                      ),
                    ),
                  ),
                ],
              ),
            ],

            /// Botones cancelación.
            if (canResolveCancellation) ...[
              const SizedBox(
                height: 10,
              ),

              Row(
                children: [

                  Expanded(
                    child:
                        OutlinedButton.icon(
                      icon:
                          const Icon(
                        Icons.close,
                      ),

                      onPressed:
                          () =>
                              _denyCancellationDialog(
                        r,
                      ),

                      label:
                          const Text(
                        'Denegar',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child:
                        ElevatedButton.icon(
                      icon:
                          const Icon(
                        Icons.check,
                      ),

                      onPressed:
                          () =>
                              _approveCancellationDialog(
                        r,
                      ),

                      label:
                          const Text(
                        'Cancelar',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construye la pestaña
  /// de solicitudes.
  Widget _buildRequestsTab(
    List<VacationRequest> all,
  ) {

    List<VacationRequest>
        filtered = all;

    // Aplica filtro.
    if (requestFilter != 'all') {

      filtered =
          all
              .where(
                (r) =>
                    r.status ==
                    requestFilter,
              )
              .toList();
    }

    // Orden descendente.
    filtered.sort((a, b) {

      final ad =
          a.createdAt ??
              DateTime(2000);

      final bd =
          b.createdAt ??
              DateTime(2000);

      return bd.compareTo(ad);
    });

    return Padding(
      padding:
          const EdgeInsets.all(12),

      child: Column(
        children: [

          Align(
            alignment:
                Alignment.centerLeft,

            child:
                _filterChips(),
          ),

          const SizedBox(
            height: 12,
          ),

          Expanded(
            child:
                _buildRequestList(
              filtered,
              emptyText:
                  'No hay solicitudes.',
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la lista
  /// de solicitudes.
  Widget _buildRequestList(
    List<VacationRequest> items, {
    required String emptyText,
  }) {

    if (items.isEmpty) {
      return Center(
        child: Text(emptyText),
      );
    }

    return ListView.builder(
      itemCount: items.length,

      itemBuilder:
          (context, index) =>
              _requestCard(
        items[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final width =
        MediaQuery.of(context)
            .size
            .width;

    final isSmall =
        width < 380;

    return StreamBuilder<
        List<VacationRequest>>(
      stream:
          repo.streamAllRequests(),

      builder:
          (context, vacationsSnap) {

        // Indicador de carga.
        if (vacationsSnap
                .connectionState ==
            ConnectionState
                .waiting) {

          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final allRequests =
            vacationsSnap.data ?? [];

        return StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream:
              employeesRepo
                  .streamEmployees(),

          builder:
              (context, employeesSnap) {

            // Indicador de carga.
            if (employeesSnap
                    .connectionState ==
                ConnectionState
                    .waiting) {

              return const Scaffold(
                body: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              );
            }

            // Conversión de empleados.
            final employees =
                (employeesSnap
                            .data
                            ?.docs ??
                        [])
                    .map(
                      Employee.fromDoc,
                    )
                    .toList()

                  ..sort(
                    (a, b) =>
                        a.name
                            .toLowerCase()
                            .compareTo(
                              b.name
                                  .toLowerCase(),
                            ),
                  );

            return StreamBuilder<
                List<Holiday>>(
              stream: holidaysRepo
                  .streamHolidaysForYear(
                visibleMonth.year,
              ),

              builder:
                  (context, holidaysSnap) {

                // Error festivos.
                if (holidaysSnap
                    .hasError) {

                  return Scaffold(
                    body: Center(
                      child: Text(
                        'Error cargando festivos: ${holidaysSnap.error}',
                      ),
                    ),
                  );
                }

                // Indicador carga.
                if (holidaysSnap
                        .connectionState ==
                    ConnectionState
                        .waiting) {

                  return const Scaffold(
                    body: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  );
                }

                final holidays =
                    holidaysSnap.data ??
                        [];

                return Scaffold(
                  appBar: AppBar(

                    title: Text(
                      widget.readOnly
                          ? 'Vacaciones'
                          : 'Gestión de vacaciones',

                      style: TextStyle(
                        fontSize:
                            isSmall
                                ? 18
                                : 20,
                      ),
                    ),

                    bottom: TabBar(
                      controller:
                          _tabController,

                      isScrollable:
                          width < 500,

                      tabs: const [

                        Tab(
                          child:
                              FittedBox(
                            child: Text(
                              'Solicitudes',
                            ),
                          ),
                        ),

                        Tab(
                          child:
                              FittedBox(
                            child: Text(
                              'Calendario',
                            ),
                          ),
                        ),

                        Tab(
                          child:
                              FittedBox(
                            child: Text(
                              'Cuadrante',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  body: SafeArea(
                    child: TabBarView(
                      controller:
                          _tabController,

                      children: [

                        /// Pestaña solicitudes.
                        _buildRequestsTab(
                          allRequests,
                        ),

                        /// Pestaña calendario.
                        VacationCalendarTab(
                          allRequests:
                              allRequests,

                          holidays:
                              holidays,

                          visibleMonth:
                              visibleMonth,

                          selectedDay:
                              selectedDay,

                          onMonthChanged:
                              _changeVisibleMonth,

                          onDaySelected:
                              (day) {

                            setState(() {
                              selectedDay =
                                  day;
                            });
                          },
                        ),

                        /// Pestaña cuadrante.
                        VacationQuadrantTab(
                          employees:
                              employees,

                          allRequests:
                              allRequests,

                          holidays:
                              holidays,

                          visibleMonth:
                              visibleMonth,

                          onMonthChanged:
                              _changeVisibleMonth,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}