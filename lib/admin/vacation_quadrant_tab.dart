import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/repositories/employees.dart';
import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/vacation_request.dart';
import 'vacation_utils.dart';

/// Pestaña del cuadrante de vacaciones.

/// Permite visualizar:
/// - Vacaciones aprobadas.
/// - Festivos.
/// - Total anual por empleado.
class VacationQuadrantTab
    extends StatelessWidget {

  /// Lista de empleados.
  final List<Employee> employees;

  /// Lista completa de solicitudes.
  final List<VacationRequest> allRequests;

  /// Lista de festivos.
  final List<Holiday> holidays;

  /// Mes visible actualmente.
  final DateTime visibleMonth;

  /// Callback para cambiar de mes.
  final void Function(int delta)
      onMonthChanged;

  const VacationQuadrantTab({
    super.key,
    required this.employees,
    required this.allRequests,
    required this.holidays,
    required this.visibleMonth,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {

    /// Días del mes visible.
    final days =
        VacationUtils.daysInMonth(
      visibleMonth,
    );

    /// Empleados ordenados alfabéticamente.
    final sortedEmployees =
        [...employees]

          ..sort(
            (a, b) => a.name
                .toLowerCase()
                .compareTo(
                  b.name.toLowerCase(),
                ),
          );

    return Column(
      children: [

        /// Cabecera superior.
        Padding(
          padding:
              const EdgeInsets.all(12),

          child: Row(
            children: [

              /// Botón mes anterior.
              IconButton(
                onPressed:
                    () =>
                        onMonthChanged(-1),

                icon: const Icon(
                  Icons.chevron_left,
                ),
              ),

              /// Título mes actual.
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat(
                      'MMMM yyyy',
                      'es_ES',
                    ).format(
                      visibleMonth,
                    ),

                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,

                      fontSize: 18,
                    ),
                  ),
                ),
              ),

              /// Botón mes siguiente.
              IconButton(
                onPressed:
                    () =>
                        onMonthChanged(1),

                icon: const Icon(
                  Icons.chevron_right,
                ),
              ),
            ],
          ),
        ),

        /// Tabla principal.
        Expanded(
          child:
              SingleChildScrollView(

            /// Scroll horizontal.
            scrollDirection:
                Axis.horizontal,

            child:
                SingleChildScrollView(

              /// Scroll vertical.
              child: DataTable(

                /// Columnas tabla.
                columns: [

                  /// Columna empleado.
                  const DataColumn(
                    label: Text(
                      'Empleado',
                    ),
                  ),

                  /// Columnas días.
                  ...days.map(
                    (d) => DataColumn(
                      label: Text(
                        '${d.day}',
                      ),
                    ),
                  ),

                  /// Columna total.
                  const DataColumn(
                    label: Text(
                      'Total',
                    ),
                  ),
                ],

                /// Filas empleados.
                rows:
                    sortedEmployees.map(
                  (employee) {

                    /// Total anual aprobado.
                    final total =
                        VacationUtils
                            .approvedAnnualDaysForEmployee(
                      employeeId:
                          employee.id,

                      all:
                          allRequests,

                      year:
                          visibleMonth
                              .year,

                      holidays:
                          holidays,
                    );

                    return DataRow(

                      cells: [

                        /// Nombre empleado.
                        DataCell(
                          Text(
                            employee.name,
                          ),
                        ),

                        /// Celdas días.
                        ...days.map(
                          (day) {

                            /// Comprueba vacaciones.
                            final hasVacation =
                                VacationUtils.employeeHasVacationOnDay(
                              employee.id,
                              day,
                              allRequests,
                              holidays,
                            );

                            /// Comprueba festivo.
                            final isHoliday =
                                VacationUtils.isHoliday(
                              day,
                              holidays,
                            );

                            /// Celda festivo.
                            if (isHoliday) {

                              return const DataCell(
                                Center(
                                  child: Text(
                                    'F',
                                  ),
                                ),
                              );
                            }

                            /// Celda vacaciones.
                            return DataCell(
                              Center(
                                child: Text(
                                  hasVacation
                                      ? 'V'
                                      : '',
                                ),
                              ),
                            );
                          },
                        ),

                        /// Total anual.
                        DataCell(
                          Text(
                            '$total',
                          ),
                        ),
                      ],
                    );
                  },
                ).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}