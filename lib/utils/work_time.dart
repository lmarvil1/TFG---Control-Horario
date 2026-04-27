import 'package:cloud_firestore/cloud_firestore.dart';

class WorkTime {
  static const int ordinaryDailyMinutes = 480; // 8 horas

  static DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dayLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.day)}/${two(d.month)}/${d.year}";
  }

  /// Cálculo robusto:
  /// - Solo empareja IN->OUT del MISMO DÍA
  /// - Ignora sesiones <=0 o demasiado largas (por defecto > 16h)
  /// - Si hay varios IN seguidos, usa el último
  /// - OUT sin IN: se ignora
  static Map<DateTime, int> minutesByDay(
    List<Map<String, dynamic>> punches, {
    int maxSessionMinutes = 16 * 60,
  }) {
    final items = punches.where((p) => p['at'] != null).toList()
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

  static int totalMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (a, b) => a + b);
  }

  static int ordinaryMinutes(int workedMinutes) {
    if (workedMinutes <= 0) return 0;
    return workedMinutes > ordinaryDailyMinutes
        ? ordinaryDailyMinutes
        : workedMinutes;
  }

  static int extraMinutes(int workedMinutes) {
    if (workedMinutes <= ordinaryDailyMinutes) return 0;
    return workedMinutes - ordinaryDailyMinutes;
  }

  static int totalOrdinaryMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (sum, dayMinutes) {
      return sum + ordinaryMinutes(dayMinutes);
    });
  }

  static int totalExtraMinutes(Map<DateTime, int> perDay) {
    return perDay.values.fold(0, (sum, dayMinutes) {
      return sum + extraMinutes(dayMinutes);
    });
  }

  static int monthMinutes(List<Map<String, dynamic>> punches, DateTime month) {
    final monthItems = punches.where((p) {
      final dt = (p['at'] as Timestamp).toDate();
      return dt.year == month.year && dt.month == month.month;
    }).toList();

    final perDay = minutesByDay(monthItems);
    return totalMinutes(perDay);
  }

  static int todayMinutes(List<Map<String, dynamic>> punches) {
    final now = DateTime.now();
    final perDay = minutesByDay(punches);
    return perDay[dayKey(now)] ?? 0;
  }

  static String formatHM(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return "${h}h ${m}m";
  }
}