import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/supabase_service.dart';
import 'feed_event.dart';
import 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final SupabaseService _supabaseService;
  StreamSubscription? _subscription;

  FeedBloc({required SupabaseService supabaseService})
      : _supabaseService = supabaseService,
        super(const FeedState()) {
    on<LoadVideos>(_onLoad);
    on<VideosUpdated>(_onUpdated);
    on<VideoPageChanged>(_onPageChanged);
    on<RefreshVideos>(_onRefresh);
    on<FeedError>(_onError);
  }

  Future<void> _onLoad(LoadVideos event, Emitter<FeedState> emit) async {
    emit(state.copyWith(status: FeedStatus.loading));
    await _subscription?.cancel();
    _subscription = _supabaseService.watchVideos().listen(
      (videos) => add(VideosUpdated(videos)),
      onError: (e) => add(FeedError(e.toString())),
    );
  }

  void _onUpdated(VideosUpdated event, Emitter<FeedState> emit) {
    emit(state.copyWith(status: FeedStatus.loaded, videos: event.videos));
  }

  void _onError(FeedError event, Emitter<FeedState> emit) {
    emit(state.copyWith(status: FeedStatus.error, errorMessage: event.message));
  }

  void _onPageChanged(VideoPageChanged event, Emitter<FeedState> emit) {
    emit(state.copyWith(currentIndex: event.index));
  }

  Future<void> _onRefresh(RefreshVideos event, Emitter<FeedState> emit) async {
    add(const LoadVideos());
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
