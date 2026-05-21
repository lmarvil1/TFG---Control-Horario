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

        /// Cabecera informativa.
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

              /// Información del festivo.
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

                  /// Mensaje cuando no hay vacaciones.
                  ? const Center(
                      child: Text(
                        'No hay trabajadores de vacaciones ese día',
                      ),
                    )

                  /// Lista de trabajadores.
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

                            /// Rango de fechas.
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

  /// Construye la cabecera del calendario.
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

        /// Nombre del mes visible.
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

  /// Construye la cuadrícula mensual.
  Widget _buildMonthGrid(
    List<VacationRequest> all,
    List<Holiday> holidays, {
    required bool compact,
  }) {

    /// Etiquetas de días de la semana.
    const weekDays = [
      'L',
      'M',
      'X',
      'J',
      'V',
      'S',
      'D',
    ];

    /// Primer día del mes.
    final firstDayOfMonth =
        DateTime(
      visibleMonth.year,
      visibleMonth.month,
      1,
    );

    /// Último día del mes.
    final lastDayOfMonth =
        DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    );

    final daysInMonth =
        lastDayOfMonth.day;

    final firstWeekday =
        firstDayOfMonth.weekday;

    /// Lista de celdas del calendario.
    final List<Widget> cells = [];

    /// Cabecera de días de la semana.
    for (final d in weekDays) {

      cells.add(
        Container(
          alignment:
              Alignment.center,

          padding:
              EdgeInsets.symmetric(
            vertical:
                compact ? 4 : 6,
          ),

          child: Text(
            d,

            style: TextStyle(
              fontWeight:
                  FontWeight.bold,

              fontSize:
                  compact ? 10 : 13,
            ),
          ),
        ),
      );
    }

    /// Espacios vacíos iniciales.
    for (
      int i = 1;
      i < firstWeekday;
      i++
    ) {

      cells.add(
        const SizedBox.shrink(),
      );
    }

    /// Generación de días del mes.
    for (
      int day = 1;
      day <= daysInMonth;
      day++
    ) {

      final date = DateTime(
        visibleMonth.year,
        visibleMonth.month,
        day,
      );

      /// Número de trabajadores de vacaciones.
      final approvedCount =
          VacationUtils
              .approvedRequestsForDay(
        date,
        all,
        holidays,
      ).length;

      /// Comprueba si el día está seleccionado.
      final isSelected =
          VacationUtils.sameDate(
        date,
        selectedDay,
      );

      /// Comprueba si el día es festivo.
      final isHoliday =
          VacationUtils.isHoliday(
        date,
        holidays,
      );

      cells.add(
        LayoutBuilder(
          builder:
              (context, constraints) {

            final cellWidth =
                constraints.maxWidth;

            /// Tamaño del número del día.
            final dayFontSize =
                compact
                    ? (cellWidth < 34
                        ? 10.0
                        : 12.0)
                    : (cellWidth < 36
                        ? 11.0
                        : cellWidth < 46
                            ? 12.0
                            : 14.0);

            /// Tamaño del badge.
            final badgeFontSize =
                compact
                    ? (cellWidth < 34
                        ? 8.0
                        : 9.0)
                    : (cellWidth < 36
                        ? 9.0
                        : 11.0);

            /// Padding horizontal del badge.
            final badgeHPadding =
                compact
                    ? (cellWidth < 38
                        ? 3.0
                        : 4.0)
                    : (cellWidth < 40
                        ? 4.0
                        : 6.0);

            /// Padding vertical del badge.
            final badgeVPadding =
                compact
                    ? 1.0
                    : (cellWidth < 40
                        ? 1.0
                        : 2.0);

            Color? backgroundColor;

            /// Fondo vacaciones.
            if (approvedCount > 0) {

              backgroundColor =
                  Colors.green
                      .withValues(
                alpha: 0.10,
              );

            }

            /// Fondo festivo.
            else if (isHoliday) {

              backgroundColor =
                  Colors.red.shade100;
            }

            return InkWell(

              /// Selección del día.
              onTap: () {
                onDaySelected(date);
              },

              child: AspectRatio(
                aspectRatio:
                    compact ? 1.25 : 1,

                child: Tooltip(
                  message: isHoliday
                      ? (VacationUtils.holidayName(
                            date,
                            holidays,
                          ) ??
                          'Festivo')
                      : '',

                  child: Container(
                    margin: EdgeInsets.all(
                      compact ? 1.5 : 2,
                    ),

                    decoration:
                        BoxDecoration(

                      border: Border.all(
                        color:
                            isSelected
                                ? Theme.of(
                                    context,
                                  )
                                      .colorScheme
                                      .primary

                                : isHoliday
                                    ? Colors.red
                                        .shade400

                                    : Colors.grey
                                        .shade300,

                        width:
                            isSelected
                                ? 2
                                : 1,
                      ),

                      borderRadius:
                          BorderRadius.circular(
                        compact ? 6 : 8,
                      ),

                      color:
                          backgroundColor,
                    ),

                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical:
                            compact
                                ? 2
                                : (cellWidth < 40
                                    ? 4
                                    : 6),

                        horizontal: 2,
                      ),

                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [

                          /// Número del día.
                          Flexible(
                            child: FittedBox(
                              fit:
                                  BoxFit.scaleDown,

                              child: Text(
                                '$day',

                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight.w700,

                                  fontSize:
                                      dayFontSize,

                                  color:
                                      isHoliday
                                          ? Colors.red
                                              .shade900

                                          : Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(
                            height:
                                compact
                                    ? 1
                                    : (cellWidth < 40
                                        ? 2
                                        : 4),
                          ),

                          /// Badge de vacaciones.
                          if (approvedCount > 0)

                            Flexible(
                              child: Container(
                                padding:
                                    EdgeInsets.symmetric(
                                  horizontal:
                                      badgeHPadding,

                                  vertical:
                                      badgeVPadding,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color:
                                      Colors.green,

                                  borderRadius:
                                      BorderRadius.circular(
                                    10,
                                  ),
                                ),

                                child:
                                    FittedBox(
                                  fit:
                                      BoxFit.scaleDown,

                                  child: Text(
                                    '$approvedCount',

                                    style:
                                        TextStyle(
                                      color:
                                          Colors.white,

                                      fontSize:
                                          badgeFontSize,

                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            )

                          /// Indicador festivo.
                          else if (isHoliday)

                            Flexible(
                              child: Text(
                                'F',

                                style:
                                    TextStyle(
                                  color:
                                      Colors.red
                                          .shade900,

                                  fontWeight:
                                      FontWeight.bold,

                                  fontSize:
                                      badgeFontSize + 1,
                                ),
                              ),
                            )

                          /// Espacio vacío.
                          else

                            SizedBox(
                              height:
                                  compact
                                      ? 8
                                      : (cellWidth < 40
                                          ? 12
                                          : 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    /// Completa la cuadrícula.
    while (cells.length % 7 != 0) {

      cells.add(
        const SizedBox.shrink(),
      );
    }

    return LayoutBuilder(
      builder:
          (context, constraints) {

        final horizontalPadding =
            constraints.maxWidth < 360
                ? 4.0
                : 8.0;

        return Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal:
                horizontalPadding,

            vertical: 4,
          ),

          child: GridView.builder(
            shrinkWrap: true,

            physics:
                const NeverScrollableScrollPhysics(),

            itemCount: cells.length,

            gridDelegate:
                SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,

              childAspectRatio:
                  compact ? 1.25 : 1.0,
            ),

            itemBuilder:
                (context, index) =>
                    cells[index],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(
      builder:
          (context, constraints) {

        final media =
            MediaQuery.of(context);

        /// Detecta orientación horizontal.
        final isLandscape =
            media.orientation ==
                Orientation.landscape;

        /// Detecta tablet o escritorio.
        final isTabletOrDesktop =
            constraints.maxWidth >= 900;

        /// Layout horizontal.
        if (isLandscape ||
            isTabletOrDesktop) {

          return Row(
            children: [

              /// Calendario.
              Expanded(
                flex: 5,

                child:
                    SingleChildScrollView(
                  padding:
                      const EdgeInsets.all(
                    12,
                  ),

                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(
                        maxWidth:
                            isTabletOrDesktop
                                ? 760
                                : 620,
                      ),

                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          _buildCalendarHeader(
                            context,
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          _buildMonthGrid(
                            allRequests,
                            holidays,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const VerticalDivider(
                width: 1,
              ),

              /// Lista lateral.
              Expanded(
                flex: 4,

                child:
                    _buildSelectedDayList(
                  context,

                  padding:
                      const EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    8,
                  ),
                ),
              ),
            ],
          );
        }

        /// Layout vertical móvil.
        return Column(
          children: [

            /// Calendario superior.
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                4,
              ),

              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 700,
                  ),

                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [

                      _buildCalendarHeader(
                        context,
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      _buildMonthGrid(
                        allRequests,
                        holidays,
                        compact: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(
              height: 1,
            ),

            /// Lista inferior.
            Expanded(
              child:
                  _buildSelectedDayList(
                context,

                padding:
                    const EdgeInsets.all(
                  12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}