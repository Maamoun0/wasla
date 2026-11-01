import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/users_repository.dart';
import '../../auth/providers/auth_provider.dart';

class ReviewsState {
  final List<Map<String, dynamic>> receivedReviews;
  final List<Map<String, dynamic>> sentReviews;
  final bool isLoadingReceived;
  final bool isLoadingSent;
  final bool hasMoreReceived;
  final bool hasMoreSent;
  final String? errorMessage;
  final bool isSubmittingReply;

  ReviewsState({
    this.receivedReviews = const [],
    this.sentReviews = const [],
    this.isLoadingReceived = false,
    this.isLoadingSent = false,
    this.hasMoreReceived = true,
    this.hasMoreSent = true,
    this.errorMessage,
    this.isSubmittingReply = false,
  });

  ReviewsState copyWith({
    List<Map<String, dynamic>>? receivedReviews,
    List<Map<String, dynamic>>? sentReviews,
    bool? isLoadingReceived,
    bool? isLoadingSent,
    bool? hasMoreReceived,
    bool? hasMoreSent,
    String? Function()? errorMessage,
    bool? isSubmittingReply,
  }) {
    return ReviewsState(
      receivedReviews: receivedReviews ?? this.receivedReviews,
      sentReviews: sentReviews ?? this.sentReviews,
      isLoadingReceived: isLoadingReceived ?? this.isLoadingReceived,
      isLoadingSent: isLoadingSent ?? this.isLoadingSent,
      hasMoreReceived: hasMoreReceived ?? this.hasMoreReceived,
      hasMoreSent: hasMoreSent ?? this.hasMoreSent,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      isSubmittingReply: isSubmittingReply ?? this.isSubmittingReply,
    );
  }
}

class ReviewsController extends StateNotifier<ReviewsState> {
  final UsersRepository _repository;
  final String? _userId;
  static const int pageSize = 20;

  ReviewsController(this._repository, this._userId) : super(ReviewsState()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    state = ReviewsState();
    await Future.wait([
      fetchReceivedReviews(isLoadMore: false),
      fetchSentReviews(isLoadMore: false),
    ]);
  }

  Future<void> fetchReceivedReviews({bool isLoadMore = false}) async {
    if (_userId == null) return;
    if (isLoadMore && (!state.hasMoreReceived || state.isLoadingReceived)) return;

    state = state.copyWith(
      isLoadingReceived: true,
      errorMessage: () => null,
    );

    try {
      final from = isLoadMore ? state.receivedReviews.length : 0;
      final to = from + pageSize - 1;

      final newReviews = await _repository.reviewsReceived(_userId, from: from, to: to);

      state = state.copyWith(
        receivedReviews: isLoadMore ? [...state.receivedReviews, ...newReviews] : newReviews,
        isLoadingReceived: false,
        hasMoreReceived: newReviews.length == pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingReceived: false,
        errorMessage: () => 'فشل تحميل التقييمات الواردة: $e',
      );
    }
  }

  Future<void> fetchSentReviews({bool isLoadMore = false}) async {
    if (_userId == null) return;
    if (isLoadMore && (!state.hasMoreSent || state.isLoadingSent)) return;

    state = state.copyWith(
      isLoadingSent: true,
      errorMessage: () => null,
    );

    try {
      final from = isLoadMore ? state.sentReviews.length : 0;
      final to = from + pageSize - 1;

      final newReviews = await _repository.reviewsSent(_userId, from: from, to: to);

      state = state.copyWith(
        sentReviews: isLoadMore ? [...state.sentReviews, ...newReviews] : newReviews,
        isLoadingSent: false,
        hasMoreSent: newReviews.length == pageSize,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSent: false,
        errorMessage: () => 'فشل تحميل التقييمات الصادرة: $e',
      );
    }
  }

  Future<void> submitReply(String reviewId, String replyText) async {
    if (_userId == null || replyText.trim().isEmpty) return;

    state = state.copyWith(
      isSubmittingReply: true,
      errorMessage: () => null,
    );

    try {
      await _repository.replyToReview(reviewId: reviewId, userId: _userId, response: replyText.trim());

      // Update local state: add reply to the corresponding review
      final updatedReceived = state.receivedReviews.map((r) {
        if (r['id'] == reviewId) {
          return {
            ...r,
            'review_responses': [
              {
                'response': replyText.trim(),
                'created_at': DateTime.now().toIso8601String(),
              }
            ],
          };
        }
        return r;
      }).toList();

      state = state.copyWith(
        receivedReviews: updatedReceived,
        isSubmittingReply: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmittingReply: false,
        errorMessage: () => 'فشل إرسال الرد: $e',
      );
      rethrow;
    }
  }
}

// ── Providers ────────────────────────────────────────────────────
final reviewsControllerProvider =
    StateNotifierProvider.autoDispose<ReviewsController, ReviewsState>((ref) {
  final repository = ref.watch(usersRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  return ReviewsController(repository, userId);
});
