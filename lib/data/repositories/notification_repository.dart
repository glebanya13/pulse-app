import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../mock/mock_data.dart';
import '../models/notification.dart';

class NotificationRepository {
  NotificationRepository(this._api) : _notifications = List.of(MockData.notifications);

  final ApiClient _api;
  final List<AppNotification> _notifications;

  Future<List<AppNotification>> list() async {
    if (Env.useMockData) return List.of(_notifications);
    final res = await _api.dio.get('/notifications');
    final items = (res.data as Map<String, dynamic>)['items'] as List;
    return items.cast<Map<String, dynamic>>().map(AppNotification.fromJson).toList();
  }

  Future<void> markRead(String id) async {
    if (Env.useMockData) {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      return;
    }
    await _api.dio.patch('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    if (Env.useMockData) {
      for (var i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      return;
    }
    await _api.dio.patch('/notifications/read-all');
  }
}
