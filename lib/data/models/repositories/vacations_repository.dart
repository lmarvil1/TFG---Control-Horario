import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'notifications_repository.dart';
import 'vacation_request.dart';

class VacationsRepository {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('vacation_requests');

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationsRepository _notificationsRepo = NotificationsRepository();

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

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

  Future<List<String>> _getAdminUids() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

    return snap.docs.map((d) => d.id).toList();
  }

  Future<String?> _getWorkerUidByEmployeeId(String employeeId) async {
    final snap = await _db
        .collection('users')
        .where('employeeId', isEqualTo: employeeId.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

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

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

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