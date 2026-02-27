import 'package:equatable/equatable.dart';

class LikeState extends Equatable {
  final bool isLiked;
  final int likeCount;
  final bool isLoading;
  final bool showAnimation;
  final String? errorMessage;

  const LikeState({
    this.isLiked = false,
    this.likeCount = 0,
    this.isLoading = false,
    this.showAnimation = false,
    this.errorMessage,
  });

  LikeState copyWith({
    bool? isLiked,
    int? likeCount,
    bool? isLoading,
    bool? showAnimation,
    String? errorMessage,
  }) {
    return LikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isLoading: isLoading ?? this.isLoading,
      showAnimation: showAnimation ?? this.showAnimation,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [isLiked, likeCount, isLoading, showAnimation, errorMessage];
}
