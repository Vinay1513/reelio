import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/video_model.dart';
import '../bloc/like_bloc.dart';
import '../bloc/like_event.dart';
import '../bloc/like_state.dart';
import 'action_buttons.dart';
import 'animated_heart.dart';

class VideoItem extends StatefulWidget {
  final VideoModel video;
  final bool isVisible;
  final VoidCallback onCommentTap;

  const VideoItem({
    super.key,
    required this.video,
    required this.isVisible,
    required this.onCommentTap,
  });

  @override
  State<VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<VideoItem> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _showPauseIcon = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  late AnimationController _heartAnimController;
  Offset _heartPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl))
          ..setLooping(true)
          ..setVolume(1.0);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        if (widget.isVisible) _controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void didUpdateWidget(VideoItem old) {
    super.didUpdateWidget(old);
    if (widget.isVisible != old.isVisible && _isInitialized) {
      if (widget.isVisible && !_isPaused) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _heartAnimController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_isInitialized) return;
    setState(() {
      _isPaused = !_isPaused;
      _showPauseIcon = true;
    });
    if (_isPaused) {
      _controller.pause();
    } else {
      _controller.play();
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  void _handleDoubleTap(TapDownDetails details) {
    setState(() => _heartPosition = details.localPosition);
    context.read<LikeBloc>().add(DoubleTapLike(widget.video.id));
    _heartAnimController.forward(from: 0);
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;

    // Request storage permission
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission required to download'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'reelio_${widget.video.id}.mp4';
      final savePath = '${dir.path}/$fileName';

      await Dio().download(
        widget.video.videoUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Video downloaded!'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0;
        });
      }
    }
  }

  Future<void> _shareVideo() async {
    try {
      await Share.share(
        'Check out this video on Reelio! 🎬\n${widget.video.videoUrl}',
        subject: widget.video.caption ?? 'Reelio Short',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share video')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // needed to trigger onDoubleTapDown
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoPlayer(),
            _buildGradientOverlay(),
            _buildVideoInfo(),
            _buildActionButtons(),
            if (_showPauseIcon) _buildPausePlayIcon(),
            if (_isDownloading) _buildDownloadProgress(),
            AnimatedHeart(
              position: _heartPosition,
              controller: _heartAnimController,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_hasError) {
      return Container(
        color: AppTheme.surfaceColor,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined,
                  color: AppTheme.textSecondary, size: 48),
              SizedBox(height: 8),
              Text('Failed to load video',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child:
              CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller.value.size.width,
        height: _controller.value.size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppTheme.videoOverlayGradient),
    );
  }

  Widget _buildVideoInfo() {
    final profile = _getCreatorProfile();
    return Positioned(
      left: 12,
      right: 80,
      bottom: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile['username']!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (widget.video.caption != null && widget.video.caption!.isNotEmpty)
            ...[
              const SizedBox(height: 6),
              Text(
                widget.video.caption!,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          const SizedBox(height: 12),
          // Music ticker
          Row(
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                'Original Sound · ${profile['displayName']}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, String> _getCreatorProfile() {
    // Use real profile if available, else pick fake one based on video id
    if (widget.video.creator != null) {
      return {
        'username':
            '@${widget.video.creator!.username}',
        'displayName':
            widget.video.creator!.displayName ?? widget.video.creator!.username,
        'avatar': widget.video.creator!.avatarUrl ?? '',
      };
    }
    // Deterministic fake profile based on video
    final idx =
        widget.video.id.codeUnitAt(0) % AppConstants.fakeProfiles.length;
    final fake = AppConstants.fakeProfiles[idx];
    return {
      'username': fake['username']!,
      'displayName': fake['displayName']!,
      'avatar': fake['avatar']!,
    };
  }

  Widget _buildActionButtons() {
    final profile = _getCreatorProfile();
    return Positioned(
      right: 8,
      bottom: 80,
      child: ActionButtons(
        video: widget.video,
        avatarUrl: profile['avatar']!,
        username: profile['username']!,
        onCommentTap: widget.onCommentTap,
        onDownloadTap: _downloadVideo,
        onShareTap: _shareVideo,
      ),
    );
  }

  Widget _buildPausePlayIcon() {
    return Center(
      child: AnimatedOpacity(
        opacity: _showPauseIcon ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPaused ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Positioned(
      top: 80,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.download_rounded,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Downloading...',
                      style:
                          TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: AppTheme.surfaceColor,
                      color: AppTheme.primaryColor,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(_downloadProgress * 100).toInt()}%',
              style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
