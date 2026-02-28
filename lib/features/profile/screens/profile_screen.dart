import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'reel_screen.dart';
import 'notifications_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/screens/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // null = current user

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _service = SupabaseService();
  UserProfile? _profile;
  List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _isFollowLoading = false;
  bool _hasPendingRequest = false;
  bool _isCurrentlyFollowing = false;
  int _totalLikes = 0;

  String get _targetUserId => widget.userId ?? _getCurrentUserId();

  String _getCurrentUserId() {
    final userId = _service.currentUserId;
    return userId ?? '';
  }

  bool get _isOwnProfile {
    final currentId = _service.currentUserId;
    return currentId == _targetUserId || widget.userId == null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print('LOAD_PROFILE - targetUserId: $_targetUserId');
    print('LOAD_PROFILE - isOwnProfile: $_isOwnProfile');
    print('LOAD_PROFILE - currentUserId: ${_service.currentUserId}');
    if (_targetUserId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserProfile? profile = await _service.getProfile(_targetUserId);
      print('LOAD_PROFILE - profile: $profile');
      print('LOAD_PROFILE - followersCount: ${profile?.followersCount}');
      print('LOAD_PROFILE - followingCount: ${profile?.followingCount}');
      print('LOAD_PROFILE - profile username: ${profile?.username}');
      print('LOAD_PROFILE - profile displayName: ${profile?.displayName}');
      
      if (profile == null && _isOwnProfile) {
        await Future.delayed(const Duration(milliseconds: 500));
        profile = await _service.getProfile(_targetUserId);
        print('LOAD_PROFILE - profile after retry: $profile');
      }
      
      final videos = await _service.getUserVideos(_targetUserId);
      final likes = await _service.getTotalLikesForUser(_targetUserId);
      
      bool hasPending = false;
      bool isFollowing = false;
      if (!_isOwnProfile) {
        hasPending = await _service.hasPendingFollowRequest(_targetUserId);
        isFollowing = await _service.isFollowing(_targetUserId);
        print('LOAD_PROFILE - isFollowing: $isFollowing');
        print('LOAD_PROFILE - hasPending: $hasPending');
      }
      
      if (mounted) {
        setState(() {
          _profile = profile;
          _videos = videos;
          _totalLikes = likes;
          _hasPendingRequest = hasPending;
          _isCurrentlyFollowing = isFollowing;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('LOAD_PROFILE - error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    final wasFollowing = _isCurrentlyFollowing;
    setState(() {
      _isFollowLoading = true;
      _isCurrentlyFollowing = !_isCurrentlyFollowing;
    });
    try {
      final isNowFollowing = await _service.toggleFollow(_targetUserId);
      if (mounted) {
        setState(() {
          _isCurrentlyFollowing = isNowFollowing;
          _profile = _profile!.copyWith(
            isFollowing: isNowFollowing,
            followersCount: isNowFollowing
                ? _profile!.followersCount + 1
                : _profile!.followersCount - 1,
          );
          _isFollowLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCurrentlyFollowing = wasFollowing;
          _isFollowLoading = false;
        });
      }
    }
  }

  Future<void> _openEditProfile() async {
    if (_profile == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: _profile!),
      ),
    );
    // Reload profile if changes were saved
    if (updated == true) _loadProfile();
  }

  Future<void> _signOut() async {
    await _service.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _loadProfile,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildProfileInfo()),
            SliverToBoxAdapter(child: _buildStats()),
            SliverToBoxAdapter(child: _buildActionButtons()),
            SliverToBoxAdapter(child: _buildVideosSectionHeader()),
            _buildVideosGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.backgroundColor,
      floating: true,
      title: Text(
        _profile?.username ?? 'Profile',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        if (_isOwnProfile) ...[
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textSecondary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            onPressed: () => _showSignOutDialog(),
          ),
        ],
      ],
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Sign Out',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _signOut();
            },
            child: const Text('Sign Out',
                style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    final profile = _profile;
    final fakeIndex = _targetUserId.isEmpty
        ? 0
        : _targetUserId.codeUnitAt(0) % 5;
    final fakeProfiles = [
      {'avatar': 'https://i.pravatar.cc/150?img=12', 'bio': '🎬 Video creator | Sharing everyday moments'},
      {'avatar': 'https://i.pravatar.cc/150?img=5', 'bio': '💃 Living life one reel at a time ✨'},
      {'avatar': 'https://i.pravatar.cc/150?img=3', 'bio': '🍕 Foodie | Explorer | Creator 🌍'},
      {'avatar': 'https://i.pravatar.cc/150?img=9', 'bio': '🌿 Wellness & positivity | Be kind 🙏'},
      {'avatar': 'https://i.pravatar.cc/150?img=7', 'bio': '🎮 Gaming | Tech | Life | Vibes 🔥'},
    ];
    final fakeAvatar = fakeProfiles[fakeIndex]['avatar']!;
    final fakeBio = fakeProfiles[fakeIndex]['bio']!;
    final avatarUrl = profile?.avatarUrl ?? fakeAvatar;
    final bio = profile?.bio ?? fakeBio;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.surfaceColor,
                  child: const Icon(Icons.person_rounded,
                      color: AppTheme.textSecondary, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Display name
          Text(
            profile?.displayName ?? profile?.username ?? 'User',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '@${profile?.username ?? 'user'}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              bio,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats() {
    final profile = _profile;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(_formatCount(_videos.length), 'Videos'),
          _verticalDivider(),
          _statItem(_formatCount(_totalLikes), 'Likes'),
          _verticalDivider(),
          _statItem(_formatCount(profile?.followersCount ?? 0), 'Followers'),
          _verticalDivider(),
          _statItem(_formatCount(profile?.followingCount ?? 0), 'Following'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(height: 32, width: 1, color: AppTheme.dividerColor);
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          if (_isOwnProfile) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openEditProfile,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.dividerColor),
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Profile'),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isFollowLoading ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCurrentlyFollowing || _hasPendingRequest
                      ? AppTheme.surfaceColor
                      : AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isFollowLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  _isCurrentlyFollowing
                      ? 'Following'
                      : _hasPendingRequest
                          ? 'Requested'
                          : 'Follow',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.dividerColor),
                foregroundColor: AppTheme.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Icon(Icons.share_rounded, size: 18),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideosSectionHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Icon(Icons.grid_on_rounded,
              color: AppTheme.textPrimary, size: 20),
          SizedBox(width: 8),
          Text('Videos',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildVideosGrid() {
    if (_videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.videocam_off_rounded,
                    color: AppTheme.textSecondary, size: 48),
                SizedBox(height: 12),
                Text('No videos yet',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 9 / 16,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final video = _videos[index];
            return _buildVideoThumbnail(video);
          },
          childCount: _videos.length,
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(VideoModel video) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelScreen(
              videos: _videos,
              initialIndex: _videos.indexOf(video),
            ),
          ),
        );
      },
      child: Container(
        color: AppTheme.surfaceColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            video.thumbnailUrl != null
                ? Image.network(video.thumbnailUrl!, fit: BoxFit.cover)
                : const Icon(Icons.play_circle_outline_rounded,
                color: AppTheme.textSecondary, size: 32),
            // Play icon overlay
            const Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                color: Colors.white54,
                size: 32,
              ),
            ),
            // Like count overlay
            Positioned(
              bottom: 6,
              left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    _formatCount(video.likeCount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4)
                        ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
