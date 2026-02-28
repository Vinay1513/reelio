import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/comment_model.dart';
import '../../../data/services/supabase_service.dart';

// Events
abstract class CommentEvent extends Equatable {
  const CommentEvent();
  @override
  List<Object?> get props => [];
}

class LoadComments extends CommentEvent {
  final String videoId;
  const LoadComments(this.videoId);
  @override
  List<Object?> get props => [videoId];
}

class CommentsUpdated extends CommentEvent {
  final List<CommentModel> comments;
  const CommentsUpdated(this.comments);
  @override
  List<Object?> get props => [comments];
}

class AddComment extends CommentEvent {
  final String videoId;
  final String comment;
  const AddComment(this.videoId, this.comment);
  @override
  List<Object?> get props => [videoId, comment];
}

// State
class CommentState extends Equatable {
  final List<CommentModel> comments;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const CommentState({
    this.comments = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  CommentState copyWith({
    List<CommentModel>? comments,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return CommentState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }

  @override
  List<Object?> get props => [comments, isLoading, isSending, error];
}

// Bloc
class CommentBloc extends Bloc<CommentEvent, CommentState> {
  final SupabaseService _service;
  StreamSubscription? _sub;

  CommentBloc({required SupabaseService supabaseService})
      : _service = supabaseService,
        super(const CommentState()) {
    on<LoadComments>(_onLoad);
    on<CommentsUpdated>(_onUpdated);
    on<AddComment>(_onAdd);
  }

  Future<void> _onLoad(LoadComments event, Emitter<CommentState> emit) async {
    emit(state.copyWith(isLoading: true));
    await _sub?.cancel();
    _sub = _service.watchComments(event.videoId).listen(
          (comments) => add(CommentsUpdated(comments)),
          onError: (e) => emit(state.copyWith(
            isLoading: false,
            error: e.toString(),
          )),
        );
  }

  void _onUpdated(CommentsUpdated event, Emitter<CommentState> emit) {
    emit(state.copyWith(comments: event.comments, isLoading: false));
  }

  Future<void> _onAdd(AddComment event, Emitter<CommentState> emit) async {
    final currentUser = await _service.getCurrentProfile();
    final tempComment = CommentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      videoId: event.videoId,
      userId: _service.currentUserId ?? '',
      comment: event.comment,
      createdAt: DateTime.now(),
      username: currentUser?.username ?? 'You',
      avatarUrl: currentUser?.avatarUrl,
    );

    final updatedComments = [tempComment, ...state.comments];
    emit(state.copyWith(comments: updatedComments, isSending: true));

    try {
      await _service.addComment(event.videoId, event.comment);
      emit(state.copyWith(isSending: false));
    } catch (e) {
      final revertedComments = state.comments.where((c) => c.id != tempComment.id).toList();
      emit(state.copyWith(comments: revertedComments, isSending: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
