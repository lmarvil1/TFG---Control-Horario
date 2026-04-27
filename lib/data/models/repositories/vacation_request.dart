import 'package:cloud_firestore/cloud_firestore.dart';

class VacationRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String status;
  final String workerComment;
  final String adminComment;
  final DateTime? createdAt;

  final String cancelRequestComment;
  final DateTime? cancelRequestedAt;
  final DateTime? cancelResolvedAt;

  VacationRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    required this.workerComment,
    required this.adminComment,
    required this.createdAt,
    required this.cancelRequestComment,
    required this.cancelRequestedAt,
    required this.cancelResolvedAt,
  });

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  VacationRequest copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? startDate,
    DateTime? endDate,
    int? days,
    String? status,
    String? workerComment,
    String? adminComment,
    DateTime? createdAt,
    String? cancelRequestComment,
    DateTime? cancelRequestedAt,
    DateTime? cancelResolvedAt,
  }) {
    return VacationRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      days: days ?? this.days,
      status: status ?? this.status,
      workerComment: workerComment ?? this.workerComment,
      adminComment: adminComment ?? this.adminComment,
      createdAt: createdAt ?? this.createdAt,
      cancelRequestComment: cancelRequestComment ?? this.cancelRequestComment,
      cancelRequestedAt: cancelRequestedAt ?? this.cancelRequestedAt,
      cancelResolvedAt: cancelResolvedAt ?? this.cancelResolvedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'startDate': Timestamp.fromDate(_dateOnly(startDate)),
      'endDate': Timestamp.fromDate(_dateOnly(endDate)),
      'days': days,
      'status': status,
      'workerComment': workerComment,
      'adminComment': adminComment,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'cancelRequestComment': cancelRequestComment,
      'cancelRequestedAt': cancelRequestedAt != null
          ? Timestamp.fromDate(cancelRequestedAt!)
          : null,
      'cancelResolvedAt': cancelResolvedAt != null
          ? Timestamp.fromDate(cancelResolvedAt!)
          : null,
    };
  }

  factory VacationRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final startTs = data['startDate'];
    final endTs = data['endDate'];
    final createdTs = data['createdAt'];
    final cancelRequestedTs = data['cancelRequestedAt'];
    final cancelResolvedTs = data['cancelResolvedAt'];

    final startDateRaw =
        startTs is Timestamp ? startTs.toDate() : DateTime.now();
    final endDateRaw =
        endTs is Timestamp ? endTs.toDate() : DateTime.now();

    return VacationRequest(
      id: doc.id,
      employeeId: (data['employeeId'] ?? '').toString(),
      employeeName: (data['employeeName'] ?? '').toString(),
      startDate: _dateOnly(startDateRaw),
      endDate: _dateOnly(endDateRaw),
      days: (data['days'] ?? 0) is int
          ? (data['days'] ?? 0) as int
          : int.tryParse('${data['days']}') ?? 0,
      status: (data['status'] ?? 'pending').toString(),
      workerComment: (data['workerComment'] ?? '').toString(),
      adminComment: (data['adminComment'] ?? '').toString(),
      createdAt: createdTs is Timestamp ? createdTs.toDate() : null,
      cancelRequestComment: (data['cancelRequestComment'] ?? '').toString(),
      cancelRequestedAt:
          cancelRequestedTs is Timestamp ? cancelRequestedTs.toDate() : null,
      cancelResolvedAt:
          cancelResolvedTs is Timestamp ? cancelResolvedTs.toDate() : null,
    );
  }
}