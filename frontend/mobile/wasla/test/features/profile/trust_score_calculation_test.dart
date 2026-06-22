import 'package:flutter_test/flutter_test.dart';

double calculateTrustScore({
  required bool isVerified,
  required double averageStars,
  required int reviewCount,
  required int monthsOld,
}) {
  double score = 0.0;
  
  // 1. Verification: 30 if verified
  if (isVerified) {
    score += 30.0;
  }
  
  // 2. Average rating: (avg / 5.0) * 40.0
  score += (averageStars / 5.0) * 40.0;
  
  // 3. Review count: 1 per review, max 20
  score += reviewCount > 20 ? 20 : reviewCount;
  
  // 4. Account age: 1 per month, max 10
  score += monthsOld > 10 ? 10 : monthsOld;
  
  return double.parse(score.toStringAsFixed(2));
}

void main() {
  group('Trust Score Formula Simulation Tests', () {
    test('Case 1: Verified + 20 reviews with 5 stars + 10 months old = 100 points', () {
      final score = calculateTrustScore(
        isVerified: true,
        averageStars: 5.0,
        reviewCount: 20,
        monthsOld: 10,
      );
      expect(score, 100.0);
    });

    test('Case 2: Unverified + 10 reviews with 4 stars + 5 months old = 47 points', () {
      final score = calculateTrustScore(
        isVerified: false,
        averageStars: 4.0,
        reviewCount: 10,
        monthsOld: 5,
      );
      // Math: 0 (verified) + (4/5)*40 [32] + 10 (reviews) + 5 (months) = 47
      expect(score, 47.0);
    });

    test('Case 3: Verified + 0 reviews + new account = 30 points', () {
      final score = calculateTrustScore(
        isVerified: true,
        averageStars: 0.0,
        reviewCount: 0,
        monthsOld: 0,
      );
      expect(score, 30.0);
    });

    test('Case 4: Unverified + 0 reviews + new account = 0 points', () {
      final score = calculateTrustScore(
        isVerified: false,
        averageStars: 0.0,
        reviewCount: 0,
        monthsOld: 0,
      );
      expect(score, 0.0);
    });

    test('Case 5: Caps limits check (e.g. 50 reviews, 24 months old, avg 4.5 stars, verified)', () {
      final score = calculateTrustScore(
        isVerified: true,
        averageStars: 4.5,
        reviewCount: 50,
        monthsOld: 24,
      );
      // Math: 30 (verified) + (4.5/5)*40 [36] + 20 (capped reviews) + 10 (capped months) = 96
      expect(score, 96.0);
    });
  });
}
