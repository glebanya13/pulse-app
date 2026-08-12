import 'enums.dart';
import 'user.dart';

class Complaint {
  final String id;
  final AppUser reporter;
  final ComplaintTargetType targetType;
  final String targetId;
  final String reason;
  final ComplaintStatus status;
  final DateTime createdAt;

  const Complaint({
    required this.id,
    required this.reporter,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) => Complaint(
        id: json['id'] as String,
        reporter: AppUser.fromJson(json['reporter'] as Map<String, dynamic>),
        targetType: ComplaintTargetType.fromBackend(json['targetType'] as String),
        targetId: json['targetId'] as String,
        reason: json['reason'] as String,
        status: ComplaintStatus.fromBackend(json['status'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AdminActionLog {
  final String id;
  final AppUser admin;
  final String action;
  final String targetType;
  final String targetId;
  final DateTime createdAt;

  const AdminActionLog({
    required this.id,
    required this.admin,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
  });

  factory AdminActionLog.fromJson(Map<String, dynamic> json) => AdminActionLog(
        id: json['id'] as String,
        admin: AppUser.fromJson(json['admin'] as Map<String, dynamic>),
        action: json['action'] as String,
        targetType: json['targetType'] as String,
        targetId: json['targetId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AdminStats {
  final int users;
  final int blockedUsers;
  final int events;
  final int activeEvents;
  final int applications;
  final int requests;
  final int complaintsOpen;
  final int reviews;

  const AdminStats({
    this.users = 0,
    this.blockedUsers = 0,
    this.events = 0,
    this.activeEvents = 0,
    this.applications = 0,
    this.requests = 0,
    this.complaintsOpen = 0,
    this.reviews = 0,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        users: json['users'] as int? ?? 0,
        blockedUsers: json['blockedUsers'] as int? ?? 0,
        events: json['events'] as int? ?? 0,
        activeEvents: json['activeEvents'] as int? ?? 0,
        applications: json['applications'] as int? ?? 0,
        requests: json['requests'] as int? ?? 0,
        complaintsOpen: json['complaintsOpen'] as int? ?? 0,
        reviews: json['reviews'] as int? ?? 0,
      );
}
