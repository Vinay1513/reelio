import 'package:equatable/equatable.dart';

abstract class LikeEvent extends Equatable {
  const LikeEvent();
  @override
  List<Object?> get props => [];
}

class InitializeLike extends LikeEvent {
  final String videoId;
  const InitializeLike(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class ToggleLike extends LikeEvent {
  final String videoId;
  const ToggleLike(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class DoubleTapLike extends LikeEvent {
  final String videoId;
  const DoubleTapLike(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class LikeCountUpdated extends LikeEvent {
  final int count;
  const LikeCountUpdated(this.count);
  @override
  List<Object?> get props => [count];
}

class IsLikedUpdated extends LikeEvent {
  final bool isLiked;
  const IsLikedUpdated(this.isLiked);
  @override
  List<Object?> get props => [isLiked];
}

class HideHeartAnimation extends LikeEvent {
  const HideHeartAnimation();
}
