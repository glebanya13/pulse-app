import 'enums.dart';
import 'event.dart';
import 'user.dart';

class EventApplication {
  final String id;
  final Event event;
  final AppUser applicant;
  final ApplicationStatus status;
  final String? message;
  final DateTime createdAt;
  final DateTime? guestConfirmedAt;
  final DateTime? hostConfirmedAt;
  final DateTime? hostMarkedNoShowAt;

  const EventApplication({
    required this.id,
    required this.event,
    required this.applicant,
    this.status = ApplicationStatus.pending,
    this.message,
    required this.createdAt,
    this.guestConfirmedAt,
    this.hostConfirmedAt,
    this.hostMarkedNoShowAt,
  });

  bool get mutualAttendanceConfirmed =>
      guestConfirmedAt != null &&
      hostConfirmedAt != null &&
      hostMarkedNoShowAt == null;

  bool get iAmGuestConfirmed => guestConfirmedAt != null;

  bool get isNoShow => hostMarkedNoShowAt != null;

  EventApplication copyWith({
    ApplicationStatus? status,
    DateTime? guestConfirmedAt,
    DateTime? hostConfirmedAt,
    DateTime? hostMarkedNoShowAt,
    bool clearNoShow = false,
  }) =>
      EventApplication(
        id: id,
        event: event,
        applicant: applicant,
        status: status ?? this.status,
        message: message,
        createdAt: createdAt,
        guestConfirmedAt: guestConfirmedAt ?? this.guestConfirmedAt,
        hostConfirmedAt: hostConfirmedAt ?? this.hostConfirmedAt,
        hostMarkedNoShowAt:
            clearNoShow ? null : (hostMarkedNoShowAt ?? this.hostMarkedNoShowAt),
      );

  factory EventApplication.fromJson(
    Map<String, dynamic> json, {
    Event? fallbackEvent,
    AppUser? fallbackApplicant,
  }) {
    final eventJson = json['event'] as Map<String, dynamic>?;
    final userJson = (json['user'] ?? json['applicant']) as Map<String, dynamic>?;
    return EventApplication(
      id: json['id'] as String,
      event: eventJson != null
          ? Event.fromJson(eventJson)
          : fallbackEvent ??
              (throw StateError(
                  'EventApplication.fromJson: no event in payload and no fallbackEvent given')),
      applicant: userJson != null
          ? AppUser.fromJson(userJson)
          : fallbackApplicant ??
              (throw StateError(
                  'EventApplication.fromJson: no user in payload and no fallbackApplicant given')),
      status: ApplicationStatus.fromBackend(json['status'] as String),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      guestConfirmedAt: json['guestConfirmedAt'] != null
          ? DateTime.parse(json['guestConfirmedAt'] as String)
          : null,
      hostConfirmedAt: json['hostConfirmedAt'] != null
          ? DateTime.parse(json['hostConfirmedAt'] as String)
          : null,
      hostMarkedNoShowAt: json['hostMarkedNoShowAt'] != null
          ? DateTime.parse(json['hostMarkedNoShowAt'] as String)
          : null,
    );
  }
}
