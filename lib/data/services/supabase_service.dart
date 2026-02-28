import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_model.dart';
import '../models/comment_model.dart';
import '../models/notification_model.dart';
import '../../core/constants/app_constants.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;
  User? get currentUser => _client.auth.currentUser;

  // ─────────────────── AUTH ───────────────────

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );

    if (response.user != null) {
      await _createProfile(response.user!.id, username, email);
    }

    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _createProfile(
      String userId, String username, String email) async {
    try {
      print('_createProfile - userId: $userId, username: $username, email: $email');
      final result = await _client.from(AppConstants.profilesTable).upsert({
        'id': userId,
        'username': username,
        'display_name': username,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });
      print('_createProfile - result: $result');
    } catch (e) {
      print('_createProfile - error: $e');
    }
  }

  Future<void> createProfile(
      String userId, String username, String email) async {
    await _createProfile(userId, username, email);
  }

  // ─────────────────── PROFILES ───────────────────

  Future<UserProfile?> getProfile(String userId) async {
    print('getProfile - userId: $userId');
    try {
      final response = await _client
          .from(AppConstants.profilesTable)
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      print('getProfile - response: $response');

      if (response == null) return null;

      final followersCount = await _getFollowerCount(userId);
      final followingCount = await _getFollowingCount(userId);
      final videosCount = await _getUserVideoCount(userId);
      final userIsFollowing = await isFollowing(userId);

      return UserProfile.fromMap({
        ...response,
        'followers_count': followersCount,
        'following_count': followingCount,
        'videos_count': videosCount,
      }).copyWith(isFollowing: userIsFollowing);
    } catch (e) {
      print('getProfile - error: $e');
      return null;
    }
  }

  Future<UserProfile?> getCurrentProfile() async {
    final id = currentUserId;
    if (id == null) return null;
    return getProfile(id);
  }

  Future<dynamic> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    File? avatarFile,
  }) async {
    final userId = currentUserId;
    print('updateProfile - currentUserId: $userId');
    if (userId == null) return;

    final updates = <String, dynamic>{};

    // Upload new avatar if provided — use a cache-busting timestamp in the URL
    if (avatarFile != null) {
      final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from(AppConstants.avatarBucket).upload(
        path,
        avatarFile,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );
      updates['avatar_url'] = _client.storage
          .from(AppConstants.avatarBucket)
          .getPublicUrl(path);
    }

    if (displayName != null && displayName.isNotEmpty) {
      updates['display_name'] = displayName;
    }
    if (username != null && username.isNotEmpty) {
      updates['username'] = username;
    }
    if (bio != null) {
      updates['bio'] = bio;
    }

    print('updateProfile - updates: $updates');
    
    if (updates.isNotEmpty) {
      try {
        final result = await _client
            .from(AppConstants.profilesTable)
            .update(updates)
            .eq('id', userId);
        print('updateProfile - result: $result');
        return result;
      } catch (e) {
        print('updateProfile - error: $e');
        rethrow;
      }
    }
    return null;
  }

  // ─────────────────── VIDEOS ───────────────────

  Stream<List<VideoModel>> watchVideos() {
    final userId = currentUserId;

    return _client
        .from(AppConstants.videosTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((maps) async {
      if (maps.isEmpty) return [];

      var videos = <VideoModel>[];
      for (final m in maps) {
        final profile = await getProfile(m['user_id'] as String);
        videos.add(VideoModel.fromMap(m).copyWith(creator: profile));
      }

      // Filter out current user's videos (show only others' videos)
      if (userId != null) {
        videos = videos.where((v) => v.userId != userId).toList();
      }

      if (userId != null) {
        final likedIds = await _getLikedVideoIds(userId);
        return videos
            .map((v) => v.copyWith(isLiked: likedIds.contains(v.id)))
            .toList();
      }
      return videos;
    });
  }

  Future<List<VideoModel>> getUserVideos(String userId) async {
    final currentId = currentUserId;
    final response = await _client
        .from(AppConstants.videosTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    Set<String> likedIds = {};
    if (currentId != null) {
      likedIds = await _getLikedVideoIds(currentId);
    }

    final videos = <VideoModel>[];
    for (final m in response) {
      final profile = await getProfile(m['user_id'] as String);
      videos.add(VideoModel.fromMap(m).copyWith(
        isLiked: likedIds.contains(m['id']),
        creator: profile,
      ));
    }
    return videos;
  }

  Future<Set<String>> _getLikedVideoIds(String userId) async {
    final response = await _client
        .from(AppConstants.likesTable)
        .select('video_id')
        .eq('user_id', userId);
    return response.map((e) => e['video_id'] as String).toSet();
  }

  Future<String> uploadVideo({
    required File file,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final videoFileName = '$userId/$timestamp.mp4';
    final thumbFileName = '$userId/${timestamp}_thumb.jpg';

    // Step 1: Extract thumbnail from video first frame
    onProgress?.call(0.05);
    String? thumbnailUrl;
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: file.path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 80,
        timeMs: 0,
      );

      if (thumbPath != null) {
        // Step 2: Upload thumbnail (10-30%)
        onProgress?.call(0.1);
        await _client.storage.from(AppConstants.videoBucket).upload(
          thumbFileName,
          File(thumbPath),
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
        thumbnailUrl = _client.storage
            .from(AppConstants.videoBucket)
            .getPublicUrl(thumbFileName);
        onProgress?.call(0.3);
      }
    } catch (_) {
      // Thumbnail extraction failed - continue without it
    }

    // Step 3: Upload video file (30-80%)
    onProgress?.call(0.3);
    await _client.storage.from(AppConstants.videoBucket).upload(
      videoFileName,
      file,
      fileOptions: const FileOptions(
        contentType: 'video/mp4',
        upsert: true,
      ),
    );
    onProgress?.call(0.8);

    // Step 4: Get video public URL
    final videoUrl = _client.storage
        .from(AppConstants.videoBucket)
        .getPublicUrl(videoFileName);

    // Step 5: Insert record with thumbnail_url
    await _client.from(AppConstants.videosTable).insert({
      'user_id': userId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'caption': caption,
      'created_at': DateTime.now().toIso8601String(),
    });

    onProgress?.call(1.0);
    return videoUrl;
  }

  // ─────────────────── LIKES ───────────────────

  Stream<int> watchLikeCount(String videoId) {
    return _client
        .from(AppConstants.likesTable)
        .stream(primaryKey: ['id'])
        .map((maps) => maps.where((m) => m['video_id'] == videoId).length);
  }

  Stream<bool> watchIsLiked(String videoId) {
    final userId = currentUserId;
    if (userId == null) return Stream.value(false);

    return _client
        .from(AppConstants.likesTable)
        .stream(primaryKey: ['id'])
        .map((maps) => maps
        .any((m) => m['video_id'] == videoId && m['user_id'] == userId));
  }

  Future<bool> toggleLike(String videoId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final existing = await _client
        .from(AppConstants.likesTable)
        .select()
        .eq('video_id', videoId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from(AppConstants.likesTable)
          .delete()
          .eq('id', existing['id']);
      return false;
    } else {
      await _client.from(AppConstants.likesTable).insert({
        'video_id': videoId,
        'user_id': userId,
      });
      return true;
    }
  }

  // ─────────────────── COMMENTS ───────────────────

  Stream<List<CommentModel>> watchComments(String videoId) {
    return _client
        .from(AppConstants.commentsTable)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((maps) async {
      final filtered = maps.where((m) => m['video_id'] == videoId).toList();
      if (filtered.isEmpty) return [];

      final comments = <CommentModel>[];
      for (final m in filtered) {
        final profile = await getProfile(m['user_id'] as String);
        comments.add(CommentModel(
          id: m['id'] as String,
          videoId: m['video_id'] as String,
          userId: m['user_id'] as String,
          comment: m['comment'] as String,
          createdAt: DateTime.parse(m['created_at'] as String),
          username: profile?.username ?? 'user',
          avatarUrl: profile?.avatarUrl,
        ));
      }
      return comments;
    });
  }

  Stream<int> watchCommentCount(String videoId) {
    return _client
        .from(AppConstants.commentsTable)
        .stream(primaryKey: ['id'])
        .map((maps) => maps.where((m) => m['video_id'] == videoId).length);
  }

  Future<void> addComment(String videoId, String comment) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from(AppConstants.commentsTable).insert({
      'video_id': videoId,
      'user_id': userId,
      'comment': comment,
    });
  }

  // ─────────────────── FOLLOWS ───────────────────

  Future<bool> isFollowing(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null || userId == targetUserId) return false;

    final result = await _client
        .from(AppConstants.followsTable)
        .select()
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    return result != null;
  }

  Future<bool> hasPendingFollowRequest(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final result = await _client
        .from(AppConstants.followRequestsTable)
        .select()
        .eq('from_user_id', userId)
        .eq('to_user_id', targetUserId)
        .maybeSingle();

    return result != null;
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    if (userId == targetUserId) throw Exception('Cannot follow yourself');

    final existing = await _client
        .from(AppConstants.followsTable)
        .select()
        .eq('follower_id', userId)
        .eq('following_id', targetUserId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from(AppConstants.followsTable)
          .delete()
          .eq('id', existing['id']);
      
      await _createNotification(
        toUserId: targetUserId,
        type: NotificationType.followAccepted,
        fromUserId: userId,
      );
      return false;
    } else {
      await _client.from(AppConstants.followRequestsTable).insert({
        'from_user_id': userId,
        'to_user_id': targetUserId,
        'status': 'pending',
      });

      await _createNotification(
        toUserId: targetUserId,
        type: NotificationType.followRequest,
        fromUserId: userId,
      );
      return true;
    }
  }

  Future<void> acceptFollowRequest(String requestId, String fromUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from(AppConstants.followsTable).insert({
      'follower_id': fromUserId,
      'following_id': userId,
    });

    await _client
        .from(AppConstants.followRequestsTable)
        .update({'status': 'accepted'})
        .eq('id', requestId);

    await _createNotification(
      toUserId: fromUserId,
      type: NotificationType.followAccepted,
      fromUserId: userId,
    );
  }

  Future<void> declineFollowRequest(String requestId) async {
    await _client
        .from(AppConstants.followRequestsTable)
        .update({'status': 'declined'})
        .eq('id', requestId);
  }

  Stream<List<Map<String, dynamic>>> watchFollowRequests() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      return _client
          .from(AppConstants.followRequestsTable)
          .stream(primaryKey: ['id'])
          .map((maps) => maps
              .where((m) =>
                  m['to_user_id'] == userId && m['status'] == 'pending')
              .toList());
    } catch (e) {
      print('watchFollowRequests error: $e');
      return Stream.value([]);
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFollowRequests() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final requests = await _client
        .from(AppConstants.followRequestsTable)
        .select()
        .eq('to_user_id', userId)
        .eq('status', 'pending');

    final requestsWithProfiles = <Map<String, dynamic>>[];
    for (final request in requests) {
      final profile = await getProfile(request['from_user_id'] as String);
      requestsWithProfiles.add({
        ...request,
        'from_username': profile?.username,
        'from_avatar_url': profile?.avatarUrl,
        'from_display_name': profile?.displayName,
      });
    }
    return requestsWithProfiles;
  }

  Future<void> _createNotification({
    required String toUserId,
    required NotificationType type,
    required String fromUserId,
    String? videoId,
  }) async {
    try {
      await _client.from(AppConstants.notificationsTable).insert({
        'user_id': toUserId,
        'from_user_id': fromUserId,
        'type': type.name,
        'video_id': videoId,
      });
    } catch (e) {
      print('_createNotification error: $e');
    }
  }

  Stream<List<AppNotification>> watchNotifications() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    try {
      return _client
          .from(AppConstants.notificationsTable)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .asyncMap((maps) async {
        final notifications = <AppNotification>[];
        for (final m in maps.where((m) => m['user_id'] == userId)) {
          final profile = await getProfile(m['from_user_id'] as String);
          notifications.add(AppNotification.fromMap(m).copyWith(
            fromUsername: profile?.username,
            fromAvatarUrl: profile?.avatarUrl,
          ));
        }
        return notifications;
      });
    } catch (e) {
      print('watchNotifications error: $e');
      return Stream.value([]);
    }
  }

  Future<int> getUnreadNotificationCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;

    final result = await _client
        .from(AppConstants.notificationsTable)
        .select()
        .eq('user_id', userId)
        .eq('is_read', false);
    return result.length;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from(AppConstants.notificationsTable)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllNotificationsAsRead() async {
    final userId = currentUserId;
    if (userId == null) return;

    await _client
        .from(AppConstants.notificationsTable)
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<int> _getFollowerCount(String userId) async {
    try {
      final result = await _client
          .from(AppConstants.followsTable)
          .select()
          .eq('following_id', userId);
      print('_getFollowerCount for $userId: ${result.length}');
      return result.length;
    } catch (e) {
      print('_getFollowerCount error: $e');
      return 0;
    }
  }

  Future<int> _getFollowingCount(String userId) async {
    try {
      final result = await _client
          .from(AppConstants.followsTable)
          .select()
          .eq('follower_id', userId);
      print('_getFollowingCount for $userId: ${result.length}');
      return result.length;
    } catch (e) {
      print('_getFollowingCount error: $e');
      return 0;
    }
  }

  Future<int> _getUserVideoCount(String userId) async {
    try {
      final result = await _client
          .from(AppConstants.videosTable)
          .select()
          .eq('user_id', userId);
      return result.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalLikesForUser(String userId) async {
    try {
      final videos = await _client
          .from(AppConstants.videosTable)
          .select('id')
          .eq('user_id', userId);
      if (videos.isEmpty) return 0;

      final videoIds = videos.map((v) => v['id'] as String).toList();
      int total = 0;
      for (final videoId in videoIds) {
        final likes = await _client
            .from(AppConstants.likesTable)
            .select()
            .eq('video_id', videoId);
        total += likes.length;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
