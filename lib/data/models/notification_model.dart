import 'package:equatable/equatable.dart';

enum NotificationType {
  followRequest,
  followAccepted,
  like,
  comment,
}

class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String fromUserId;
  final NotificationType type;
  final String? videoId;
  final String? message;
  final bool isRead;
  final DateTime createdAt;
  final String? fromUsername;
  final String? fromAvatarUrl;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.fromUserId,
    required this.type,
    this.videoId,
    this.message,
    this.isRead = false,
    required this.createdAt,
    this.fromUsername,
    this.fromAvatarUrl,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fromUserId: map['from_user_id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.followRequest,
      ),
      videoId: map['video_id'] as String?,
      message: map['message'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? fromUserId,
    NotificationType? type,
    String? videoId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? fromUsername,
    String? fromAvatarUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fromUserId: fromUserId ?? this.fromUserId,
      type: type ?? this.type,
      videoId: videoId ?? this.videoId,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      fromUsername: fromUsername ?? this.fromUsername,
      fromAvatarUrl: fromAvatarUrl ?? this.fromAvatarUrl,
    );
  }

  String get displayMessage {
    switch (type) {
      case NotificationType.followRequest:
        return 'wants to follow you';
      case NotificationType.followAccepted:
        return 'started following you';
      case NotificationType.like:
        return 'liked your video';
      case NotificationType.comment:
        return 'commented on your video';
    }
  }

  @override
  List<Object?> get props => [id, userId, fromUserId, type, videoId, isRead, createdAt];
}
