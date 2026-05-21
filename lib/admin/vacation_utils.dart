import '../data/models/repositories/holiday.dart';
import '../data/models/repositories/vacation_request.dart';

/// Clase auxiliar con lógica compartida
/// entre el calendario y el cuadrante de vacaciones.

/// Centraliza cálculos y comprobaciones reutilizables.
class VacationUtils {

  /// Comprueba si dos fechas corresponden
  /// exactamente al mismo día.
  static bool sameDate(
    DateTime a,
    DateTime b,
  ) {

    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  /// Comprueba si una fecha corresponde
  /// a sábado o domingo.
  static bool isWeekend(
    DateTime day,
  ) {

    return day.weekday ==
            DateTime.saturday ||
        day.weekday ==
            DateTime.sunday;
  }

  /// Comprueba si un día es festivo
  /// según la lista recibida.
  static bool isHoliday(
    DateTime day,
    List<Holiday> holidays,
  ) {

    return holidays.any(
      (h) => sameDate(
        h.date,
        day,
      ),
    );
  }

  /// Devuelve el nombre del festivo
  /// correspondiente al día indicado.
  static String? holidayName(
    DateTime day,
    List<Holiday> holidays,
  ) {

    for (final h in holidays) {

      if (sameDate(h.date, day)) {
        return h.name;
      }
    }

    return null;
  }

  /// Comprueba si una solicitud
  /// cubre un día concreto.
  static bool requestCoversDay(
    VacationRequest r,
    DateTime day,
  ) {

    final d = DateTime(
      day.year,
      day.month,
      day.day,
    );

    final start = DateTime(
      r.startDate.year,
      r.startDate.month,
      r.startDate.day,
    );

    final end = DateTime(
      r.endDate.year,
      r.endDate.month,
      r.endDate.day,
    );

    return !d.isBefore(start) &&
        !d.isAfter(end);
  }

  /// Comprueba si un día cuenta
  /// como vacaciones aprobadas.
  /// No se consideran fines de semana
  /// ni festivos.
  static bool isApprovedVacationDay(
    VacationRequest r,
    DateTime day,
    List<Holiday> holidays,
  ) {

    return r.status == 'approved' &&
        !isWeekend(day) &&
        !isHoliday(day, holidays) &&
        requestCoversDay(r, day);
  }

  /// Obtiene todas las solicitudes aprobadas
  /// para un día concreto.
  static List<VacationRequest>
      approvedRequestsForDay(
    DateTime day,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) {

    return all.where((r) {

      return isApprovedVacationDay(
        r,
        day,
        holidays,
      );

    }).toList();
  }

  /// Comprueba si un empleado tiene
  /// vacaciones aprobadas un día concreto.
  static bool employeeHasVacationOnDay(
    String employeeId,
    DateTime day,
    List<VacationRequest> all,
    List<Holiday> holidays,
  ) {

    return all.any(
      (r) =>
          r.employeeId == employeeId &&
          isApprovedVacationDay(
            r,
            day,
            holidays,
          ),
    );
  }

  /// Devuelve todos los días
  /// del mes visible.
  static List<DateTime> daysInMonth(
    DateTime visibleMonth,
  ) {

    final lastDay = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;

    return List.generate(
      lastDay,
      (index) => DateTime(
        visibleMonth.year,
        visibleMonth.month,
        index + 1,
      ),
    );
  }

  /// Calcula los días laborables
  /// dentro de un rango y un año concreto.
  static int workingDaysInRangeWithinYear({
    required DateTime start,
    required DateTime end,
    required int year,
    required List<Holiday> holidays,
  }) {

    final rangeStart = DateTime(
      start.year,
      start.month,
      start.day,
    );

    final rangeEnd = DateTime(
      end.year,
      end.month,
      end.day,
    );

    final yearStart =
        DateTime(year, 1, 1);

    final yearEnd =
        DateTime(year, 12, 31);

    /// Ajusta el inicio efectivo.
    final effectiveStart =
        rangeStart.isBefore(yearStart)
            ? yearStart
            : rangeStart;

    /// Ajusta el fin efectivo.
    final effectiveEnd =
        rangeEnd.isAfter(yearEnd)
            ? yearEnd
            : rangeEnd;

    /// Si el rango es inválido.
    if (effectiveEnd.isBefore(
      effectiveStart,
    )) {

      return 0;
    }

    int count = 0;

    DateTime current =
        effectiveStart;

    /// Recorre todos los días del rango.
    while (!current.isAfter(
      effectiveEnd,
    )) {

      /// Cuenta únicamente días laborables.
      if (!isWeekend(current) &&
          !isHoliday(
            current,
            holidays,
          )) {

        count++;
      }

      current = current.add(
        const Duration(days: 1),
      );
    }

    return count;
  }

  /// Calcula el total anual de días aprobados
  /// para un empleado.
  static int approvedAnnualDaysForEmployee({
    required String employeeId,
    required List<VacationRequest> all,
    required int year,
    required List<Holiday> holidays,
  }) {

    return all
        .where(
          (r) =>
              r.employeeId ==
                  employeeId &&
              r.status ==
                  'approved',
        )
        .fold<int>(
      0,
      (total, r) {

        return total +
            workingDaysInRangeWithinYear(
              start: r.startDate,
              end: r.endDate,
              year: year,
              holidays: holidays,
            );
      },
    );
  }
}