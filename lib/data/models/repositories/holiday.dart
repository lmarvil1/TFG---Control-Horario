import 'package:cloud_firestore/cloud_firestore.dart';

class Holiday {
  final DateTime date;
  final String name;
  final String scope;

  Holiday({
    required this.date,
    required this.name,
    this.scope = 'variable',
  });

  static DateTime dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  factory Holiday.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final rawName = map['name'];
    final rawScope = map['scope'];

    DateTime parsedDate;

    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate().toLocal();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate.toLocal();
    } else {
      parsedDate = DateTime.tryParse('${rawDate ?? ''}')?.toLocal() ??
          DateTime.now().toLocal();
    }

    return Holiday(
      date: dateOnly(parsedDate),
      name: (rawName ?? '').toString().trim(),
      scope: (rawScope ?? 'variable').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(dateOnly(date)),
      'name': name.trim(),
      'scope': scope.trim(),
    };
  }

  String get key =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}