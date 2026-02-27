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

class FeedScreen extends StatefulWidget {
  final bool isVisible;

  const FeedScreen({super.key, this.isVisible = true});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late PageController _pageController;
  final SupabaseService _service = SupabaseService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showComments(BuildContext context, String videoId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BlocProvider(
        create: (_) =>
            CommentBloc(supabaseService: _service)..add(LoadComments(videoId)),
        child: CommentSheet(videoId: videoId),
      ),
    );
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
                    index == state.currentIndex && widget.isVisible;

                return BlocProvider(
                  create: (_) =>
                      LikeBloc(supabaseService: _service)
                        ..add(InitializeLike(video.id)),
                  child: VideoItem(
                    video: video,
                    isVisible: isVisible,
                    onCommentTap: () => _showComments(context, video.id),
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
