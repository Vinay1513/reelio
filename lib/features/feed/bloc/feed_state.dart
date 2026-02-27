import 'package:equatable/equatable.dart';
import '../../../data/models/video_model.dart';

enum FeedStatus { initial, loading, loaded, error }

class FeedState extends Equatable {
  final FeedStatus status;
  final List<VideoModel> videos;
  final int currentIndex;
  final String? errorMessage;

  const FeedState({
    this.status = FeedStatus.initial,
    this.videos = const [],
    this.currentIndex = 0,
    this.errorMessage,
  });

  FeedState copyWith({
    FeedStatus? status,
    List<VideoModel>? videos,
    int? currentIndex,
    String? errorMessage,
  }) {
    return FeedState(
      status: status ?? this.status,
      videos: videos ?? this.videos,
      currentIndex: currentIndex ?? this.currentIndex,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, videos, currentIndex, errorMessage];
}
