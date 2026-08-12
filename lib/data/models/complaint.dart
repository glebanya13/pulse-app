import 'enums.dart';

/// A filed complaint about a user/event, or (targetType == support) a
/// general support request - see backend/src/complaints.
class Complaint {
  final String id;
  final ComplaintTargetType targetType;
  final String reason;
  final ComplaintStatus status;
  final DateTime createdAt;

  const Complaint({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String,
        targetType: ComplaintTargetType.fromBackend(json['targetType'] as String),
        reason: json['reason'] as String,
        status: ComplaintStatus.fromBackend(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
