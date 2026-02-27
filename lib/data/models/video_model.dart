import 'package:equatable/equatable.dart';

class VideoModel extends Equatable {
  final String id;
  final String videoUrl;
  final String userId;
  final String? caption;
  final String? thumbnailUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final DateTime createdAt;
  final UserProfile? creator;

  const VideoModel({
    required this.id,
    required this.videoUrl,
    required this.userId,
    this.caption,
    this.thumbnailUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    required this.createdAt,
    this.creator,
  });

  factory VideoModel.fromMap(Map<String, dynamic> map, {bool isLiked = false}) {
    UserProfile? creator;
    if (map['profiles'] != null) {
      creator = UserProfile.fromMap(map['profiles'] as Map<String, dynamic>);
    }
    return VideoModel(
      id: map['id'] as String,
      videoUrl: map['video_url'] as String,
      userId: map['user_id'] as String? ?? '',
      caption: map['caption'] as String?,
      thumbnailUrl: map['thumbnail_url'] as String?,
      likeCount: map['like_count'] as int? ?? 0,
      commentCount: map['comment_count'] as int? ?? 0,
      isLiked: isLiked,
      createdAt: DateTime.parse(map['created_at'] as String),
      creator: creator,
    );
  }

  VideoModel copyWith({
    String? id,
    String? videoUrl,
    String? userId,
    String? caption,
    String? thumbnailUrl,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    DateTime? createdAt,
    UserProfile? creator,
  }) {
    return VideoModel(
      id: id ?? this.id,
      videoUrl: videoUrl ?? this.videoUrl,
      userId: userId ?? this.userId,
      caption: caption ?? this.caption,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      creator: creator ?? this.creator,
    );
  }

  @override
  List<Object?> get props => [
        id, videoUrl, userId, caption, thumbnailUrl,
        likeCount, commentCount, isLiked, createdAt
      ];
}

class UserProfile extends Equatable {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final int videosCount;
  final bool isFollowing;

  const UserProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
    this.videosCount = 0,
    this.isFollowing = false,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? 'user',
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      followersCount: map['followers_count'] as int? ?? 0,
      followingCount: map['following_count'] as int? ?? 0,
      videosCount: map['videos_count'] as int? ?? 0,
      isFollowing: false,
    );
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? videosCount,
    bool? isFollowing,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      videosCount: videosCount ?? this.videosCount,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [
        id, username, displayName, avatarUrl, bio,
        followersCount, followingCount, videosCount, isFollowing
      ];
}
