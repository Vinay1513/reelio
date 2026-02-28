import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/supabase_service.dart';
import '../bloc/comment_bloc.dart';
import '../bloc/feed_bloc.dart';
import '../bloc/feed_event.dart';
import '../bloc/feed_state.dart';
import '../bloc/like_bloc.dart';
import '../bloc/like_event.dart';
import '../widgets/comment_sheet.dart';
import '../widgets/video_item.dart';
import '../../profile/screens/profile_screen.dart';

class FeedScreen extends StatefulWidget {
  final bool isVisible;

  const FeedScreen({super.key, this.isVisible = true});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final SupabaseService _service = SupabaseService();
  final Map<String, int> _commentCounts = {};
  bool _isScreenActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      setState(() => _isScreenActive = false);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => _isScreenActive = true);
    }
  }

  int _getCommentCount(String videoId, int defaultCount) {
    return _commentCounts[videoId] ?? defaultCount;
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _showComments(BuildContext context, String videoId, int defaultCount) async {
    _commentCounts[videoId] = defaultCount;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider(
        create: (_) =>
            CommentBloc(supabaseService: _service)..add(LoadComments(videoId)),
        child: CommentSheet(videoId: videoId),
      ),
    );
    
    if (mounted) {
      final newCount = await _service.watchCommentCount(videoId).first;
      _commentCounts[videoId] = newCount;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          FeedBloc(supabaseService: _service)..add(const LoadVideos()),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppTheme.backgroundColor,
        body: BlocBuilder<FeedBloc, FeedState>(
          builder: (context, state) {
            if (state.status == FeedStatus.loading && state.videos.isEmpty) {
              return const Center(
                child:
                    CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (state.status == FeedStatus.error && state.videos.isEmpty) {
              return _buildErrorState(context);
            }

            if (state.videos.isEmpty) {
              return _buildEmptyState();
            }

            return PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.videos.length,
              onPageChanged: (i) =>
                  context.read<FeedBloc>().add(VideoPageChanged(i)),
              itemBuilder: (context, index) {
                final video = state.videos[index];
                final isVisible =
                    index == state.currentIndex && widget.isVisible && _isScreenActive;
                final commentCount = _getCommentCount(video.id, video.commentCount);

                return BlocProvider(
                  create: (_) =>
                      LikeBloc(supabaseService: _service)
                        ..add(InitializeLike(video.id)),
                  child: VideoItem(
                    video: video.copyWith(commentCount: commentCount),
                    isVisible: isVisible,
                    onCommentTap: () => _showComments(context, video.id, video.commentCount),
                    onProfileTap: () => _navigateToProfile(context, video.userId),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text('Failed to load videos',
              style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<FeedBloc>().add(const LoadVideos()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded,
              color: AppTheme.textSecondary, size: 64),
          SizedBox(height: 16),
          Text('No videos yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Be the first to upload a short!',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
