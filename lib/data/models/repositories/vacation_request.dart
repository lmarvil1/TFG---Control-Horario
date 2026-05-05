import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa una solicitud de vacaciones.
/// Contiene la información necesaria para gestionar el ciclo completo
/// de una solicitud: creación, aprobación, rechazo y posible cancelación.
class VacationRequest {
  /// Identificador del documento en Firestore.
  final String id;

  /// Identificador del empleado que realiza la solicitud.
  final String employeeId;

  /// Nombre del empleado.
  final String employeeName;

  /// Fecha de inicio de las vacaciones.
  final DateTime startDate;

  /// Fecha de fin de las vacaciones.
  final DateTime endDate;

  /// Número total de días solicitados.
  final int days;

  /// Estado actual de la solicitud (pending, approved, rejected, cancelled.
  final String status;

  /// Comentario añadido por el trabajador.
  final String workerComment;

  /// Comentario añadido por el administrador.
  final String adminComment;

  /// Fecha de creación de la solicitud.
  final DateTime? createdAt;

  /// Comentario introducido al solicitar la cancelación.
  final String cancelRequestComment;

  /// Fecha en la que se solicita la cancelación.
  final DateTime? cancelRequestedAt;

  /// Fecha en la que se resuelve la cancelación.
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

  /// Normaliza una fecha eliminando la parte de hora.
  /// Esto evita inconsistencias al comparar o almacenar días completos.
  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Crea una copia del objeto modificando solo los campos indicados.
  /// Este método resulta útil para actualizar datos sin alterar
  /// directamente la instancia original.
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

  /// Convierte el objeto VacationRequest en un mapa compatible con Firestore.
  /// Se utiliza al guardar o actualizar solicitudes en la base de datos.
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

  /// Crea una instancia de VacationRequest a partir de un documento Firestore.
  /// Incluye conversiones seguras para evitar errores si algún campo
  /// no existe o llega con un formato inesperado.
  factory VacationRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final startTs = data['startDate'];
    final endTs = data['endDate'];
    final createdTs = data['createdAt'];
    final cancelRequestedTs = data['cancelRequestedAt'];
    final cancelResolvedTs = data['cancelResolvedAt'];

    // Conversión de fechas desde Timestamp de Firestore.
    // Si no existe una fecha válida, se utiliza la fecha actual como respaldo.
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