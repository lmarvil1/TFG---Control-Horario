import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'notifications_repository.dart';
import 'vacation_request.dart';

/// Repositorio encargado de gestionar las solicitudes de vacaciones.
/// Centraliza el acceso a Firestore y contiene la lógica asociada a:
/// - creación de solicitudes
/// - aprobación o rechazo
/// - cancelación de solicitudes
/// - envío de notificaciones a trabajadores y administradores
class VacationsRepository {
  /// Colección de Firestore donde se almacenan las solicitudes de vacaciones.
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('vacation_requests');

  /// Instancia general de Firestore para acceder a otras colecciones.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Repositorio utilizado para crear notificaciones internas.
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  /// Normaliza una fecha eliminando la parte de hora.
  /// Esto permite comparar y almacenar días completos sin depender
  /// de la hora exacta seleccionada.
  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Ejecuta una tarea asíncrona sin bloquear el flujo principal.
  /// Se utiliza para enviar notificaciones después de actualizar Firestore,
  /// evitando que un fallo en la notificación afecte a la operación principal.
  void _runDetached(Future<void> Function() task) {
    Future<void>(() async {
      try {
        await task();
      } catch (e, st) {
        debugPrint('Error en tarea desacoplada de vacaciones: $e');
        debugPrint('$st');
      }
    });
  }

  /// Devuelve en tiempo real todas las solicitudes de vacaciones.
  /// Las solicitudes se ordenan por fecha de creación, mostrando primero
  /// las más recientes.
  Stream<List<VacationRequest>> streamAllRequests() {
    return _col.snapshots().map((snap) {
      final items = snap.docs.map(VacationRequest.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  /// Devuelve en tiempo real las solicitudes de vacaciones de un empleado.
  /// Parámetro:
  /// - employeeId: identificador del empleado.
  Stream<List<VacationRequest>> streamEmployeeRequests(String employeeId) {
    return _col
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((snap) {
      final items = snap.docs.map(VacationRequest.fromDoc).toList()
        ..sort((a, b) {
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      return items;
    });
  }

  /// Obtiene los identificadores de todos los usuarios administradores.
  Future<List<String>> _getAdminUids() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    return snap.docs.map((d) => d.id).toList();
  }

  /// Obtiene el UID del usuario asociado a un empleado concreto.
  /// Se utiliza para poder notificar al trabajador a partir de su employeeId.
  Future<String?> _getWorkerUidByEmployeeId(String employeeId) async {
    final snap = await _db
        .collection('users')
        .where('employeeId', isEqualTo: employeeId.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Envía una notificación a todos los administradores.
  Future<void> _notifyAdmins({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? relatedType,
  }) async {
    final adminUids = await _getAdminUids();

    if (adminUids.isEmpty) {
      debugPrint('No hay admins para notificar.');
      return;
    }

    for (final uid in adminUids) {
      await _notificationsRepo.createNotification(
        recipientUid: uid,
        title: title,
        body: body,
        type: type,
        relatedId: relatedId,
        relatedType: relatedType,
      );
    }
  }

  /// Envía una notificación al trabajador correspondiente.
  Future<void> _notifyWorker({
    required String employeeId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
    String? relatedType,
  }) async {
    final workerUid = await _getWorkerUidByEmployeeId(employeeId);

    if (workerUid == null || workerUid.trim().isEmpty) {
      debugPrint('No se encontró workerUid para employeeId=$employeeId');
      return;
    }

    await _notificationsRepo.createNotification(
      recipientUid: workerUid,
      title: title,
      body: body,
      type: type,
      relatedId: relatedId,
      relatedType: relatedType,
    );
  }

  /// Formatea una fecha en formato dd/mm/yyyy.
  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  /// Crea una nueva solicitud de vacaciones.
  /// La solicitud se guarda inicialmente con estado 'pending' y se notifica
  /// a los administradores para su revisión.
  Future<void> createRequest({
    required String employeeId,
    required String employeeName,
    required DateTime startDate,
    required DateTime endDate,
    required int days,
    String workerComment = '',
  }) async {
    final normalizedStart = _dateOnly(startDate);
    final normalizedEnd = _dateOnly(endDate);

    final docRef = await _col.add({
      'employeeId': employeeId.trim(),
      'employeeName': employeeName.trim(),
      'startDate': Timestamp.fromDate(normalizedStart),
      'endDate': Timestamp.fromDate(normalizedEnd),
      'days': days,
      'status': 'pending',
      'workerComment': workerComment.trim(),
      'adminComment': '',
      'createdAt': FieldValue.serverTimestamp(),
      'cancelRequestComment': '',
      'cancelRequestedAt': null,
      'cancelResolvedAt': null,
    });

    try {
      await _notifyAdmins(
        title: 'Nueva solicitud de vacaciones',
        body:
            '$employeeName ha solicitado vacaciones del '
            '${_fmtDate(normalizedStart)} al ${_fmtDate(normalizedEnd)}.',
        type: 'vacation_requested',
        relatedId: docRef.id,
        relatedType: 'vacation_request',
      );
    } catch (e) {
      debugPrint('Error enviando notificación de vacaciones al admin: $e');
    }
  }

  /// Aprueba una solicitud de vacaciones.
  /// Actualiza el estado de la solicitud y notifica al trabajador.
  Future<void> approveRequest(String requestId) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final employeeId = (data['employeeId'] as String?)?.trim() ?? '';
    final startTs = data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();

    await _col.doc(requestId).update({
      'status': 'approved',
      'adminComment': '',
      'cancelRequestComment': '',
      'cancelRequestedAt': null,
      'cancelResolvedAt': null,
    });

    _runDetached(() async {
      await _notifyWorker(
        employeeId: employeeId,
        title: 'Vacaciones aprobadas',
        body: (start != null && end != null)
            ? 'Tus vacaciones del ${_fmtDate(start)} al ${_fmtDate(end)} han sido aprobadas.'
            : 'Tu solicitud de vacaciones ha sido aprobada.',
        type: 'vacation_approved',
        relatedId: requestId,
        relatedType: 'vacation_request',
      );
    });
  }

  /// Rechaza una solicitud de vacaciones.
  /// Guarda el comentario del administrador y notifica al trabajador.
  Future<void> rejectRequest(String requestId, String adminComment) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final employeeId = (data['employeeId'] as String?)?.trim() ?? '';
    final startTs = data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();

    await _col.doc(requestId).update({
      'status': 'rejected',
      'adminComment': adminComment.trim(),
      'cancelResolvedAt': null,
    });

    _runDetached(() async {
      await _notifyWorker(
        employeeId: employeeId,
        title: 'Vacaciones rechazadas',
        body: (start != null && end != null)
            ? 'Tu solicitud de vacaciones del ${_fmtDate(start)} al ${_fmtDate(end)} ha sido rechazada.'
            : 'Tu solicitud de vacaciones ha sido rechazada.',
        type: 'vacation_rejected',
        relatedId: requestId,
        relatedType: 'vacation_request',
      );
    });
  }

  /// Cancela directamente una solicitud que todavía está pendiente.
  /// Solo se permite cancelar solicitudes cuyo estado sea 'pending'.
  Future<void> cancelPendingRequest(String requestId) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final status = (data['status'] as String?)?.trim() ?? '';

    if (status != 'pending') {
      throw Exception('Solo se pueden cancelar solicitudes pendientes');
    }

    await _col.doc(requestId).update({
      'status': 'cancelled',
      'cancelResolvedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Solicita la cancelación de unas vacaciones ya aprobadas.
  /// Cambia el estado a 'cancel_requested' y notifica a los administradores
  /// para que aprueben o rechacen la cancelación.
  Future<void> requestCancellation(
    String requestId, {
    String cancelRequestComment = '',
  }) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final employeeName =
        (data['employeeName'] as String?)?.trim() ?? 'Un trabajador';
    final startTs = data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();

    await _col.doc(requestId).update({
      'status': 'cancel_requested',
      'cancelRequestComment': cancelRequestComment.trim(),
      'cancelRequestedAt': FieldValue.serverTimestamp(),
      'cancelResolvedAt': null,
      'adminComment': '',
    });

    _runDetached(() async {
      String periodText = 'sus vacaciones';
      if (start != null && end != null) {
        periodText = 'sus vacaciones del ${_fmtDate(start)} al ${_fmtDate(end)}';
      }

      await _notifyAdmins(
        title: 'Solicitud de cancelación',
        body: '$employeeName ha solicitado cancelar $periodText.',
        type: 'vacation_cancel_requested',
        relatedId: requestId,
        relatedType: 'vacation_request',
      );
    });
  }

  /// Aprueba la cancelación de unas vacaciones.
  /// La solicitud pasa a estado 'cancelled' y se notifica al trabajador.
  Future<void> approveCancellation(String requestId) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final employeeId = (data['employeeId'] as String?)?.trim() ?? '';
    final startTs = data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();

    await _col.doc(requestId).update({
      'status': 'cancelled',
      'cancelResolvedAt': FieldValue.serverTimestamp(),
      'adminComment': '',
    });

    _runDetached(() async {
      await _notifyWorker(
        employeeId: employeeId,
        title: 'Cancelación aprobada',
        body: (start != null && end != null)
            ? 'Se ha aprobado la cancelación de tus vacaciones del ${_fmtDate(start)} al ${_fmtDate(end)}.'
            : 'Se ha aprobado la cancelación de tus vacaciones.',
        type: 'vacation_cancel_approved',
        relatedId: requestId,
        relatedType: 'vacation_request',
      );
    });
  }

  /// Deniega la cancelación de unas vacaciones.
  /// La solicitud vuelve al estado 'approved' y se registra el comentario
  /// del administrador.
  Future<void> denyCancellation(String requestId, String adminComment) async {
    final snap = await _col.doc(requestId).get();
    final data = snap.data();
    if (data == null) return;

    final employeeId = (data['employeeId'] as String?)?.trim() ?? '';
    final startTs = data['startDate'] as Timestamp?;
    final endTs = data['endDate'] as Timestamp?;
    final start = startTs?.toDate();
    final end = endTs?.toDate();

    await _col.doc(requestId).update({
      'status': 'approved',
      'adminComment': adminComment.trim(),
      'cancelResolvedAt': FieldValue.serverTimestamp(),
    });

    _runDetached(() async {
      await _notifyWorker(
        employeeId: employeeId,
        title: 'Cancelación denegada',
        body: (start != null && end != null)
            ? 'Se ha denegado la cancelación de tus vacaciones del ${_fmtDate(start)} al ${_fmtDate(end)}.'
            : 'Se ha denegado la cancelación de tus vacaciones.',
        type: 'vacation_cancel_denied',
        relatedId: requestId,
        relatedType: 'vacation_request',
      );
    });
  }
}