import 'enums.dart';

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.payload = const {},
  });

  bool get isPositive => type == NotificationType.applicationAccepted;
  bool get isNegative => type == NotificationType.applicationRejected;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: NotificationType.fromBackend(json['type'] as String),
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        payload: payload,
      );
}
