import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AnimatedHeart extends StatelessWidget {
  final Offset position;
  final AnimationController controller;

  const AnimatedHeart({
    super.key,
    required this.position,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (controller.value == 0 || controller.value == 1) {
          return const SizedBox.shrink();
        }

        final opacity = controller.value < 0.5
            ? controller.value * 2
            : (1 - controller.value) * 2;
        final scale = 0.5 + controller.value * 1.5;

        return Positioned(
          left: position.dx - 40,
          top: position.dy - 40,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: const Icon(
                Icons.favorite_rounded,
                color: AppTheme.heartLiked,
                size: 80,
                shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
              ),
            ),
          ),
        );
      },
    );
  }
}
