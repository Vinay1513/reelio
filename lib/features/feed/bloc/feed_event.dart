import 'package:equatable/equatable.dart';
import '../../../data/models/video_model.dart';

abstract class FeedEvent extends Equatable {
  const FeedEvent();
  @override
  List<Object?> get props => [];
}

class LoadVideos extends FeedEvent {
  const LoadVideos();
}

class RefreshVideos extends FeedEvent {
  const RefreshVideos();
}

class VideosUpdated extends FeedEvent {
  final List<VideoModel> videos;
  const VideosUpdated(this.videos);
  @override
  List<Object?> get props => [videos];
}

class VideoPageChanged extends FeedEvent {
  final int index;
  const VideoPageChanged(this.index);
  @override
  List<Object?> get props => [index];
}

class FeedError extends FeedEvent {
  final String message;
  const FeedError(this.message);
  @override
  List<Object?> get props => [message];
}
