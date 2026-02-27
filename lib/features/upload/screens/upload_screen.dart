import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/supabase_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final SupabaseService _service = SupabaseService();
  final TextEditingController _captionController = TextEditingController();

  XFile? _selectedVideo;
  VideoPlayerController? _previewController;

  /// Thumbnail extracted from the first frame of the selected video.
  File? _thumbnailFile;
  bool _isGeneratingThumb = false;

  bool _isUploading = false;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (video == null) return;

    await _previewController?.dispose();

    final controller = VideoPlayerController.file(File(video.path));
    await controller.initialize();

    if (!mounted) return;

    setState(() {
      _selectedVideo = video;
      _previewController = controller;
      _thumbnailFile = null;
      _isGeneratingThumb = true;
    });

    controller.play();
    controller.setLooping(true);

    // Extract thumbnail in background after picking
    _extractThumbnail(video.path);
  }

  /// Grab first frame of the video as a JPEG using video_thumbnail.
  Future<void> _extractThumbnail(String videoPath) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 85,
        timeMs: 0, // first frame
      );

      if (mounted) {
        setState(() {
          _thumbnailFile = thumbPath != null ? File(thumbPath) : null;
          _isGeneratingThumb = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGeneratingThumb = false);
    }
  }

  Future<void> _upload() async {
    if (_selectedVideo == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      _previewController?.pause();

      await _service.uploadVideo(
        file: File(_selectedVideo!.path),
        caption: _captionController.text.trim(),
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Short uploaded!'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _previewController?.dispose();
        setState(() {
          _selectedVideo = null;
          _previewController = null;
          _thumbnailFile = null;
          _captionController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _previewController?.play();
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('New Short'),
        actions: [
          if (_selectedVideo != null && !_isUploading)
            TextButton(
              onPressed: _upload,
              child: const Text(
                'Post',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildVideoArea(),
            _buildThumbnailSection(),
            _buildCaptionField(),
            if (_isUploading) _buildUploadProgress(),
            _buildTips(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ───────────────────── VIDEO AREA ─────────────────────

  Widget _buildVideoArea() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickVideo,
      child: Container(
        margin: const EdgeInsets.all(16),
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: _selectedVideo != null && _previewController != null
              ? _buildVideoPreview()
              : _buildPickerPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _previewController!.value.size.width,
            height: _previewController!.value.size.height,
            child: VideoPlayer(_previewController!),
          ),
        ),
        // Change button
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _isUploading ? null : _pickVideo,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Change',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        // Duration
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(_previewController!.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        // Thumb badge
        Positioned(
          bottom: 12,
          right: 12,
          child: _buildThumbStatusBadge(),
        ),
      ],
    );
  }

  Widget _buildThumbStatusBadge() {
    if (_isGeneratingThumb) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child:
                  CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
            ),
            SizedBox(width: 6),
            Text('Generating cover...',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
    }
    if (_thumbnailFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_rounded, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text('Cover ready',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildPickerPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.video_library_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Select a Video',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('MP4 or MOV · Up to 3 minutes',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  // ───────────────────── THUMBNAIL SECTION ─────────────────────

  Widget _buildThumbnailSection() {
    if (_selectedVideo == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _thumbnailFile != null
                ? Colors.green.withValues(alpha: 0.3)
                : AppTheme.dividerColor,
          ),
        ),
        child: Row(
          children: [
            // ── Thumbnail preview ──
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 96,
                child: _isGeneratingThumb
                    ? Container(
                        color: AppTheme.cardColor,
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor, strokeWidth: 2),
                        ),
                      )
                    : _thumbnailFile != null
                        ? Image.file(_thumbnailFile!, fit: BoxFit.cover)
                        : Container(
                            color: AppTheme.cardColor,
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: AppTheme.textSecondary, size: 24),
                            ),
                          ),
              ),
            ),

            const SizedBox(width: 14),

            // ── Status column ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cover Thumbnail',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  if (_isGeneratingThumb)
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded,
                            color: AppTheme.textSecondary, size: 14),
                        SizedBox(width: 5),
                        Text('Extracting first frame...',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    )
                  else if (_thumbnailFile != null) ...[
                    const Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 14),
                        SizedBox(width: 5),
                        Text('Auto-generated from first frame',
                            style:
                                TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Shown in your profile grid & feed previews.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _extractThumbnail(_selectedVideo!.path),
                      child: const Text(
                        '↺  Regenerate',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 14),
                        SizedBox(width: 5),
                        Text('Could not generate thumbnail',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Video will be uploaded without a cover image.',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _extractThumbnail(_selectedVideo!.path),
                      child: const Text(
                        '↺  Try Again',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── CAPTION ─────────────────────

  Widget _buildCaptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Caption',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _captionController,
            maxLines: 3,
            maxLength: 300,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Write a caption for your short...',
              counterStyle: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────── UPLOAD PROGRESS ─────────────────────

  Widget _buildUploadProgress() {
    final String stepLabel;
    if (_uploadProgress < 0.1) {
      stepLabel = 'Extracting thumbnail...';
    } else if (_uploadProgress < 0.3) {
      stepLabel = 'Uploading thumbnail...';
    } else if (_uploadProgress < 0.8) {
      stepLabel = 'Uploading video...';
    } else {
      stepLabel = 'Saving to database...';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(stepLabel,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text('${(_uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: AppTheme.cardColor,
                color: AppTheme.primaryColor,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── TIPS ─────────────────────

  Widget _buildTips() {
    const tips = [
      '📱 Vertical videos perform best',
      '⏱️ 15–60 seconds = maximum engagement',
      '🖼️ First frame becomes your cover thumbnail',
      '✍️ Catchy captions drive more shares',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates_rounded,
                    color: AppTheme.primaryColor, size: 18),
                SizedBox(width: 8),
                Text('Pro Tips',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(t,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
