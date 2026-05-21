import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/vacation_request.dart';
import 'vacation_utils.dart';

/// Pestaña del calendario de vacaciones.

/// Permite visualizar:
/// - Vacaciones aprobadas.
/// - Festivos.
/// - Trabajadores ausentes por día.
class VacationCalendarTab extends StatelessWidget {

  /// Lista completa de solicitudes.
  final List<VacationRequest> allRequests;

  /// Lista de festivos.
  final List<Holiday> holidays;

  /// Mes visible actualmente.
  final DateTime visibleMonth;

  /// Día seleccionado actualmente.
  final DateTime selectedDay;

  /// Callback para cambiar de mes.
  final void Function(int delta)
      onMonthChanged;

  /// Callback al seleccionar un día.
  final void Function(DateTime day)
      onDaySelected;

  VacationCalendarTab({
    super.key,
    required this.allRequests,
    required this.holidays,
    required this.visibleMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });

  /// Formato utilizado para mostrar fechas.
  final DateFormat df =
      DateFormat('dd/MM/yyyy', 'es_ES');

  /// Construye la lista de trabajadores
  /// de vacaciones el día seleccionado.
  Widget _buildSelectedDayList(
    BuildContext context, {
    EdgeInsetsGeometry padding =
        const EdgeInsets.all(12),
  }) {

    /// Solicitudes aprobadas del día.
    final approvedForSelectedDay =
        VacationUtils.approvedRequestsForDay(
      selectedDay,
      allRequests,
      holidays,
    );

    final width =
        MediaQuery.of(context)
            .size
            .width;

    final isSmall =
        width < 380;

    /// Nombre del festivo si existe.
    final holidayName =
        VacationUtils.holidayName(
      selectedDay,
      holidays,
    );

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        /// Cabecera de información.
        Padding(
          padding: padding,

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [

              /// Título principal.
              Text(
                'Vacaciones el ${df.format(selectedDay)}',

                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,

                  fontSize:
                      isSmall
                          ? 14
                          : 16,
                ),
              ),

              /// Texto festivo.
              if (holidayName != null) ...[
                const SizedBox(
                  height: 4,
                ),

                Text(
                  'Festivo: $holidayName',

                  style: TextStyle(
                    color:
                        Colors.red
                            .shade700,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),

        /// Lista de trabajadores.
        Expanded(
          child:
              approvedForSelectedDay
                      .isEmpty

                  /// Mensaje vacío.
                  ? const Center(
                      child: Text(
                        'No hay trabajadores de vacaciones ese día',
                      ),
                    )

                  /// Lista de empleados.
                  : ListView.builder(
                      itemCount:
                          approvedForSelectedDay
                              .length,

                      itemBuilder:
                          (
                            context,
                            index,
                          ) {

                        final r =
                            approvedForSelectedDay[
                                index];

                        return Card(
                          margin:
                              const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),

                          child: ListTile(

                            /// Icono trabajador.
                            leading:
                                const Icon(
                              Icons.person,
                            ),

                            /// Nombre trabajador.
                            title: Text(
                              r.employeeName,

                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),

                            /// Periodo vacaciones.
                            subtitle: Text(
                              '${df.format(r.startDate)} - ${df.format(r.endDate)}',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Construye la cabecera
  /// del calendario.
  Widget _buildCalendarHeader(
    BuildContext context,
  ) {

    final width =
        MediaQuery.of(context)
            .size
            .width;

    final isSmall =
        width < 380;

    return Row(
      children: [

        /// Botón mes anterior.
        IconButton(
          visualDensity:
              VisualDensity.compact,

          onPressed:
              () => onMonthChanged(-1),

          icon: const Icon(
            Icons.chevron_left,
          ),
        ),

        /// Título del mes.
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,

              child: Text(
                DateFormat(
                  'MMMM yyyy',
                  'es_ES',
                ).format(visibleMonth),

                style: TextStyle(
                  fontSize:
                      isSmall
                          ? 16
                          : 18,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        /// Botón mes siguiente.
        IconButton(
          visualDensity:
              VisualDensity.compact,

          onPressed:
              () => onMonthChanged(1),

          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [

        /// Cabecera del calendario.
        Padding(
          padding:
              const EdgeInsets.all(12),

          child:
              _buildCalendarHeader(
            context,
          ),
        ),

        /// Lista de trabajadores.
        Expanded(
          child:
              _buildSelectedDayList(
            context,
          ),
        ),
      ],
    );
  }
}