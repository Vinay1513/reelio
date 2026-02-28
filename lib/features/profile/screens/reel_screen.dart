import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../feed/bloc/comment_bloc.dart';
import '../../feed/bloc/like_bloc.dart';
import '../../feed/bloc/like_event.dart';
import '../../feed/widgets/video_item.dart';
import '../../feed/widgets/comment_sheet.dart';
import 'profile_screen.dart';

class ReelScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const ReelScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> {
  late PageController _pageController;
  final SupabaseService _service = SupabaseService();
  int _currentIndex = 0;
  late List<VideoModel> _videos;
  final Map<String, int> _commentCounts = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _videos = List.from(widget.videos);
    for (var video in _videos) {
      _commentCounts[video.id] = video.commentCount;
    }
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _getCommentCount(String videoId) {
    return _commentCounts[videoId] ?? 
           _videos.firstWhere((v) => v.id == videoId, orElse: () => _videos.first).commentCount;
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId),
      ),
    );
  }

  Future<void> _showComments(BuildContext context, String videoId, int videoIndex) async {
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
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final video = _videos[index];
          final isVisible = index == _currentIndex;
          final commentCount = _getCommentCount(video.id);

          return BlocProvider(
            create: (_) =>
                LikeBloc(supabaseService: _service)
                  ..add(InitializeLike(video.id)),
            child: VideoItem(
              video: video.copyWith(commentCount: commentCount),
              isVisible: isVisible,
              onCommentTap: () => _showComments(context, video.id, index),
              onProfileTap: () => _navigateToProfile(context, video.userId),
            ),
          );
        },
      ),
    );
  }
}
