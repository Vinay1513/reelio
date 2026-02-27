import 'package:equatable/equatable.dart';

class CommentModel extends Equatable {
  final String id;
  final String videoId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final String? username;
  final String? avatarUrl;

  const CommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.username,
    this.avatarUrl,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    String? username;
    String? avatarUrl;

    if (map['profiles'] != null) {
      final profile = map['profiles'] as Map<String, dynamic>;
      username = profile['username'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
    }

    return CommentModel(
      id: map['id'] as String,
      videoId: map['video_id'] as String,
      userId: map['user_id'] as String,
      comment: map['comment'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      username: username,
      avatarUrl: avatarUrl,
    );
  }

  @override
  List<Object?> get props => [id, videoId, userId, comment, createdAt];
}
