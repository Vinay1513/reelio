import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/video_model.dart';
import '../models/comment_model.dart';
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
      final isFollowing = await _isFollowing(userId);

      return UserProfile.fromMap({
        ...response,
        'followers_count': followersCount,
        'following_count': followingCount,
        'videos_count': videosCount,
      }).copyWith(isFollowing: isFollowing);
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

  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    File? avatarFile,
  }) async {
    final userId = currentUserId;
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

    if (updates.isNotEmpty) {
      await _client
          .from(AppConstants.profilesTable)
          .update(updates)
          .eq('id', userId);
    }
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

      final videos = maps.map((m) => VideoModel.fromMap(m)).toList();

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

    return response
        .map((m) =>
        VideoModel.fromMap(m).copyWith(isLiked: likedIds.contains(m['id'])))
        .toList();
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
        .map((maps) => maps
        .where((m) => m['video_id'] == videoId)
        .map((m) => CommentModel.fromMap(m))
        .toList());
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

  Future<bool> _isFollowing(String targetUserId) async {
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
      return false;
    } else {
      await _client.from(AppConstants.followsTable).insert({
        'follower_id': userId,
        'following_id': targetUserId,
      });
      return true;
    }
  }

  Future<int> _getFollowerCount(String userId) async {
    try {
      final result = await _client
          .from(AppConstants.followsTable)
          .select()
          .eq('following_id', userId);
      return result.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getFollowingCount(String userId) async {
    try {
      final result = await _client
          .from(AppConstants.followsTable)
          .select()
          .eq('follower_id', userId);
      return result.length;
    } catch (_) {
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
