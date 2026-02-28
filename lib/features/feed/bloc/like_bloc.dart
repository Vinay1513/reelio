import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/supabase_service.dart';
import 'like_event.dart';
import 'like_state.dart';

class LikeBloc extends Bloc<LikeEvent, LikeState> {
  final SupabaseService _supabaseService;
  StreamSubscription? _countSub;
  StreamSubscription? _isLikedSub;

  LikeBloc({required SupabaseService supabaseService})
      : _supabaseService = supabaseService,
        super(const LikeState()) {
    on<InitializeLike>(_onInit);
    on<ToggleLike>(_onToggle);
    on<DoubleTapLike>(_onDoubleTap);
    on<LikeCountUpdated>(_onCountUpdated);
    on<IsLikedUpdated>(_onIsLikedUpdated);
    on<HideHeartAnimation>(_onHideAnimation);
  }

  Future<void> _onInit(InitializeLike event, Emitter<LikeState> emit) async {
    await _countSub?.cancel();
    await _isLikedSub?.cancel();

    _countSub = _supabaseService
        .watchLikeCount(event.videoId)
        .listen((c) => add(LikeCountUpdated(c)));

    _isLikedSub = _supabaseService
        .watchIsLiked(event.videoId)
        .listen((v) => add(IsLikedUpdated(v)));
  }

  Future<void> _onToggle(ToggleLike event, Emitter<LikeState> emit) async {
    final wasLiked = state.isLiked;
    final previousCount = state.likeCount;
    
    emit(state.copyWith(
      isLiked: !wasLiked,
      likeCount: wasLiked ? previousCount - 1 : previousCount + 1,
      isLoading: true, 
      errorMessage: null,
    ));
    
    try {
      final isLiked = await _supabaseService.toggleLike(event.videoId);
      emit(state.copyWith(
          isLiked: isLiked, isLoading: false, showAnimation: isLiked));
      if (isLiked) {
        Future.delayed(
            const Duration(milliseconds: 800), () => add(const HideHeartAnimation()));
      }
    } catch (e) {
      emit(state.copyWith(
        isLiked: wasLiked,
        likeCount: previousCount,
        isLoading: false,
        errorMessage: e.toString().contains('authenticated') ? 'Sign in to like videos' : null,
      ));
    }
  }

  Future<void> _onDoubleTap(DoubleTapLike event, Emitter<LikeState> emit) async {
    if (!state.isLiked) {
      add(ToggleLike(event.videoId));
    } else {
      emit(state.copyWith(showAnimation: true));
      Future.delayed(
          const Duration(milliseconds: 800), () => add(const HideHeartAnimation()));
    }
  }

  void _onCountUpdated(LikeCountUpdated event, Emitter<LikeState> emit) {
    emit(state.copyWith(likeCount: event.count));
  }

  void _onIsLikedUpdated(IsLikedUpdated event, Emitter<LikeState> emit) {
    emit(state.copyWith(isLiked: event.isLiked));
  }

  void _onHideAnimation(HideHeartAnimation event, Emitter<LikeState> emit) {
    emit(state.copyWith(showAnimation: false));
  }

  @override
  Future<void> close() {
    _countSub?.cancel();
    _isLikedSub?.cancel();
    return super.close();
  }
}
