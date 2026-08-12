import '../api/api_client.dart';
import '../models/admin.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/user.dart';

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<List<AppUser>> listUsers() async {
    final res = await _api.dio.get('/admin/users', queryParameters: {'limit': 100});
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }

  Future<AppUser> setBlocked(String userId, bool isBlocked) async {
    final res = await _api.dio.patch('/admin/users/$userId/block', data: {'isBlocked': isBlocked});
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Event>> listEvents({EventStatus? status}) async {
    final res = await _api.dio.get('/admin/events', queryParameters: {
      'limit': 100,
      if (status != null) 'status': status.backend,
    });
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map((e) => Event.fromJson(e)).toList();
  }

  Future<Event> cancelEvent(String eventId) async {
    final res = await _api.dio.patch('/admin/events/$eventId/cancel');
    return Event.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Event> approveEvent(String eventId) async {
    final res = await _api.dio.post('/admin/events/$eventId/approve');
    return Event.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Event> rejectEvent(String eventId) async {
    final res = await _api.dio.post('/admin/events/$eventId/reject');
    return Event.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Event> boostEvent(String eventId, {int days = 7}) async {
    final res = await _api.dio.post(
      '/admin/events/$eventId/boost',
      data: {'days': days},
    );
    return Event.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> grantOrganizerPro(String userId, {int days = 30}) async {
    final res = await _api.dio.post(
      '/admin/users/$userId/organizer-pro',
      data: {'days': days},
    );
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<Complaint>> listComplaints() async {
    final res = await _api.dio.get('/admin/complaints', queryParameters: {'limit': 100});
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(Complaint.fromJson).toList();
  }

  Future<Complaint> updateComplaint(String complaintId, ComplaintStatus status) async {
    final res =
        await _api.dio.patch('/admin/complaints/$complaintId', data: {'status': status.backend});
    return Complaint.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AdminActionLog>> listLogs() async {
    final res = await _api.dio.get('/admin/logs', queryParameters: {'limit': 100});
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(AdminActionLog.fromJson).toList();
  }

  Future<AdminStats> stats() async {
    final res = await _api.dio.get('/admin/stats');
    return AdminStats.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AuthorOfMonthShowcase> authorOfMonth() async {
    final res = await _api.dio.get('/admin/authors/month');
    return AuthorOfMonthShowcase.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<AppUser>> authorPool() async {
    final res = await _api.dio.get('/admin/authors/pool');
    final items = (res.data as Map<String, dynamic>)['items'] as List? ?? const [];
    return items.cast<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }

  Future<AuthorOfMonthShowcase> setAuthorOfMonth(String userId, {String? note}) async {
    final res = await _api.dio.post('/admin/authors/month', data: {
      'userId': userId,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return AuthorOfMonthShowcase.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> setSpecialProject(String userId, bool enabled) async {
    final res = await _api.dio.patch(
      '/admin/users/$userId/special-project',
      data: {'enabled': enabled},
    );
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }
}
