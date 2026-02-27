import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/supabase_service.dart';
import '../bloc/like_bloc.dart';
import '../bloc/like_event.dart';
import '../bloc/like_state.dart';

class ActionButtons extends StatefulWidget {
  final VideoModel video;
  final String avatarUrl;
  final String username;
  final VoidCallback onCommentTap;
  final VoidCallback onDownloadTap;
  final VoidCallback onShareTap;

  const ActionButtons({
    super.key,
    required this.video,
    required this.avatarUrl,
    required this.username,
    required this.onCommentTap,
    required this.onDownloadTap,
    required this.onShareTap,
  });

  @override
  State<ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<ActionButtons> {
  late Stream<int> _commentCountStream;

  @override
  void initState() {
    super.initState();
    _commentCountStream =
        SupabaseService().watchCommentCount(widget.video.id);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LikeBloc, LikeState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      },
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(),
            const SizedBox(height: 24),
            _buildLikeButton(context, state),
            _buildLabel(_formatCount(state.likeCount)),
            const SizedBox(height: 18),
            _buildCommentButton(),
            _buildCommentCount(),
            const SizedBox(height: 18),
            _buildIconButton(
              icon: Icons.download_rounded,
              onTap: widget.onDownloadTap,
            ),
            const SizedBox(height: 18),
            _buildIconButton(
              icon: Icons.share_rounded,
              onTap: widget.onShareTap,
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: ClipOval(
            child: widget.avatarUrl.isNotEmpty
                ? Image.network(
                    widget.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
        ),
        Positioned(
          bottom: -8,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
    );
  }

  Widget _buildLikeButton(BuildContext context, LikeState state) {
    return GestureDetector(
      onTap: () =>
          context.read<LikeBloc>().add(ToggleLike(widget.video.id)),
      child: AnimatedScale(
        scale: state.showAnimation ? 1.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          state.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: state.isLiked ? AppTheme.heartLiked : Colors.white,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildCommentButton() {
    return GestureDetector(
      onTap: widget.onCommentTap,
      child: const Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _buildCommentCount() {
    return StreamBuilder<int>(
      stream: _commentCountStream,
      builder: (context, snapshot) {
        return _buildLabel(_formatCount(snapshot.data ?? 0));
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
