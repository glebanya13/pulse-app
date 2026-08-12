import '../../core/config/env.dart';
import '../api/api_client.dart';
import '../models/complaint.dart';
import '../models/enums.dart';

class ComplaintRepository {
  ComplaintRepository(this._api);

  final ApiClient _api;
  final List<Complaint> _mockComplaints = [];

  Future<void> file({
    required ComplaintTargetType targetType,
    required String targetId,
    required String reason,
  }) async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      _mockComplaints.insert(
        0,
        Complaint(
          id: 'c_${DateTime.now().microsecondsSinceEpoch}',
          targetType: targetType,
          reason: reason,
          status: ComplaintStatus.open,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }
    await _api.dio.post('/complaints', data: {
      'targetType': targetType.backend,
      'targetId': targetId,
      'reason': reason,
    });
  }

  /// The current user's own filed complaints/support requests, newest first.
  Future<List<Complaint>> mine() async {
    if (Env.useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return List.of(_mockComplaints);
    }
    final res = await _api.dio.get('/complaints/mine');
    return (res.data as List).cast<Map<String, dynamic>>().map(Complaint.fromJson).toList();
  }
}
