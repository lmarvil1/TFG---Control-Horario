import 'package:cloud_firestore/cloud_firestore.dart';

/// Clase auxiliar para calcular tiempos de trabajo a partir de fichajes.

/// Agrupa la lógica relacionada con:
/// - cálculo de minutos trabajados
/// - horas ordinarias
/// - horas extra
/// - totales diarios y mensuales
class WorkTime {
  /// Minutos correspondientes a una jornada ordinaria de 8 horas.
  static const int ordinaryDailyMinutes = 480;

  /// Devuelve una fecha normalizada sin hora.
  /// Se utiliza como clave para agrupar fichajes por día.
  static DateTime dayKey(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  /// Devuelve una fecha en formato dd/mm/yyyy.
  static String dayLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  /// Calcula los minutos trabajados por día a partir de una lista de fichajes.
  
  /// Criterios:
  /// - Solo se emparejan fichajes de entrada y salida del mismo día.
  /// - Se ignoran sesiones con duración negativa o nula.
  /// - Se ignoran sesiones superiores al máximo permitido.
  /// - Si hay varias entradas seguidas, se utiliza la última.
  /// - Las salidas sin entrada previa se ignoran.
  static Map<DateTime, int> minutesByDay(
    List<Map<String, dynamic>> punches, {
    int maxSessionMinutes = 16 * 60,
  }) {
    final items = punches.where((p) => p['at'] is Timestamp).toList()
      ..sort((a, b) {
        final aTime = (a['at'] as Timestamp).toDate();
        final bTime = (b['at'] as Timestamp).toDate();
        return aTime.compareTo(bTime);
      });

    final Map<DateTime, int> totals = {};
    DateTime? lastIn;

    for (final p in items) {
      final type = (p['type'] ?? '').toString();
      final dt = (p['at'] as Timestamp).toDate();

      if (type == 'in') {
        lastIn = dt;
        continue;
      }

      if (type == 'out') {
        if (lastIn == null) continue;

        if (dayKey(lastIn) != dayKey(dt)) {
          lastIn = null;
          continue;
        }

        final diff = dt.difference(lastIn).inMinutes;

        if (diff <= 0 || diff > maxSessionMinutes) {
          lastIn = null;
          continue;
        }

        final k = dayKey(dt);
        totals[k] = (totals[k] ?? 0) + diff;

        lastIn = null;
      }
    }

    return totals;
  }

  /// Calcula el total de minutos trabajados.
  static int totalMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (a, b) => a + b);
  }

  /// Calcula los minutos ordinarios de un día.
  /// Como máximo se contabilizan 480 minutos ordinarios.
  static int ordinaryMinutes(int workedMinutes) {
    if (workedMinutes <= 0) return 0;

    return workedMinutes > ordinaryDailyMinutes
        ? ordinaryDailyMinutes
        : workedMinutes;
  }

  /// Calcula los minutos extra de un día.
  /// Solo se consideran extras los minutos que superan
  /// la jornada ordinaria.
  static int extraMinutes(int workedMinutes) {
    if (workedMinutes <= ordinaryDailyMinutes) return 0;

    return workedMinutes - ordinaryDailyMinutes;
  }

  /// Calcula el total de minutos ordinarios acumulados.
  static int totalOrdinaryMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (total, dayMinutes) {
      return total + ordinaryMinutes(dayMinutes);
    });
  }

  /// Calcula el total de minutos extra acumulados.
  static int totalExtraMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (total, dayMinutes) {
      return total + extraMinutes(dayMinutes);
    });
  }

  /// Calcula los minutos trabajados durante un mes concreto.
  static int monthMinutes(
    List<Map<String, dynamic>> punches,
    DateTime month,
  ) {
    final monthItems = punches.where((p) {
      final ts = p['at'];

      if (ts is! Timestamp) return false;

      final dt = ts.toDate();

      return dt.year == month.year && dt.month == month.month;
    }).toList();

    final perDay = minutesByDay(monthItems);
    return totalMinutes(perDay);
  }

  /// Calcula los minutos trabajados en el día actual.
  static int todayMinutes(List<Map<String, dynamic>> punches) {
    final now = DateTime.now();
    final perDay = minutesByDay(punches);

    return perDay[dayKey(now)] ?? 0;
  }

  /// Formatea minutos en formato de horas y minutos.
  
  /// Ejemplo:
  /// 125 minutos -> 2h 5m
  static String formatHM(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;

    return "${h}h ${m}m";
  }
}