import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/profile/screens/my_reviews_screen.dart';

import '../../helpers/fake_backend.dart';

FakeBackend _reviews({bool replyFails = false}) => FakeBackend({
      'GET /rest/v1/reviews': (req) => req.url.queryParameters.containsKey('reviewed_user_id')
          ? [
              {
                'id': 'r1',
                'rating': 4,
                'comment': 'تعامل ممتاز',
                'created_at': '2026-10-05T10:00:00Z',
                'reviewer': {'full_name': 'منى'},
                'review_responses': [],
              },
            ]
          : [
              {
                'id': 'r2',
                'rating': 2,
                'comment': 'اتأخر في الرد',
                'created_at': '2026-10-04T10:00:00Z',
                'reviewed': {'full_name': 'كريم'},
                'review_responses': [
                  {'response': 'آسف على التأخير', 'created_at': '2026-10-05T10:00:00Z'}
                ],
              },
            ],
      'POST /rest/v1/review_responses': (_) => replyFails ? const Failure(403, 'denied') : null,
    });

void main() {
  testWidgets('lists received and sent reviews for the signed-in user', (tester) async {
    final backend = _reviews();
    await pumpScreen(tester, const MyReviewsScreen(), backend: backend);

    expect(find.text('منى'), findsOneWidget);
    expect(find.text('تعامل ممتاز'), findsOneWidget);
    expect(find.text('رد على التقييم'), findsOneWidget);
    final received = backend.to('/rest/v1/reviews').map((r) => r.url.queryParameters).toList();
    expect(received.any((q) => q['reviewed_user_id'] == 'eq.u1' && q['status'] == 'eq.active'), isTrue);
    expect(received.any((q) => q['reviewer_id'] == 'eq.u1'), isTrue);

    await tester.tap(find.text('تقييمات صادرة'));
    await tester.pumpAndSettle();
    expect(find.text('كريم'), findsOneWidget);
    expect(find.text('اتأخر في الرد'), findsOneWidget);
    expect(find.text('الرد المستلم:'), findsOneWidget);
    expect(find.text('آسف على التأخير'), findsOneWidget);
  });

  testWidgets('replying sends the trimmed text and shows it under the review', (tester) async {
    final backend = _reviews();
    await pumpScreen(tester, const MyReviewsScreen(), backend: backend);

    await tester.tap(find.text('رد على التقييم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  شكراً ليكي  ');
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();

    expect(backend.lastBody('/rest/v1/review_responses'), {'review_id': 'r1', 'user_id': 'u1', 'response': 'شكراً ليكي'});
    expect(find.text('تم إرسال ردك بنجاح.'), findsOneWidget);
    expect(find.text('ردك:'), findsOneWidget);
    expect(find.text('شكراً ليكي'), findsOneWidget);
    expect(find.text('رد على التقييم'), findsNothing);
  });

  testWidgets('a refused reply says so and leaves the review unanswered', (tester) async {
    final backend = _reviews(replyFails: true);
    await pumpScreen(tester, const MyReviewsScreen(), backend: backend);

    await tester.tap(find.text('رد على التقييم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'رد');
    await tester.tap(find.text('إرسال'));
    await tester.pumpAndSettle();

    expect(find.textContaining('فشل إرسال الرد'), findsWidgets);
    expect(find.text('رد على التقييم'), findsOneWidget);
  });

  testWidgets('no reviews yet: both tabs explain what will appear', (tester) async {
    final backend = FakeBackend();
    await pumpScreen(tester, const MyReviewsScreen(), backend: backend);

    expect(find.text('لا توجد تقييمات واردة بعد'), findsOneWidget);
    await tester.tap(find.text('تقييمات صادرة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد تقييمات صادرة بعد'), findsOneWidget);
  });
}
