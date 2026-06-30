import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/wasla_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _slides = const [
    _Slide(
      emoji: '🔍',
      title: 'ابحث بسهولة',
      desc: 'آلاف الإعلانات في مدينتك —\nخدمات، وظائف، عقارات وأكثر',
      gradientColors: [Color(0xFF0D7A84), Color(0xFF0DA0AC)],
    ),
    _Slide(
      emoji: '📢',
      title: 'انشر مجاناً',
      desc: 'أضف إعلانك خلال دقيقتين\nويصل لآلاف الباحثين في منطقتك',
      gradientColors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
    ),
    _Slide(
      emoji: '⚡',
      title: 'تواصل مباشر',
      desc: 'بدون وسيط — اتصل أو واتساب\nmع المعلن مباشرة بضغطة واحدة',
      gradientColors: [Color(0xFF15803D), Color(0xFF16A34A)],
    ),
  ];

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: AppDurations.normal,
        curve: Curves.easeInOut,
      );
    } else {
      context.go(AppRoutes.auth);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ─────────────────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.auth),
                child: const Text(
                  'تخطي',
                  style: TextStyle(color: AppColors.neutral400, fontFamily: 'Cairo'),
                ),
              ),
            ),

            // ── Pages ─────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
              ),
            ),

            // ── Indicator + Button ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: AppDurations.normal,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width:  i == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? AppColors.primary600
                              : AppColors.neutral200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Button
                  PrimaryButton(
                    label: _currentPage == _slides.length - 1 ? 'ابدأ الآن' : 'التالي',
                    onPressed: _next,
                    icon: _currentPage < _slides.length - 1
                        ? Icons.arrow_back_rounded
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.gradientColors,
  });
  final String emoji;
  final String title;
  final String desc;
  final List<Color> gradientColors;
}

class _SlideWidget extends StatelessWidget {
  const _SlideWidget({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: slide.gradientColors,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.gradientColors.last.withOpacity(0.3),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Center(
              child: Text(slide.emoji, style: const TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: 48),

          // Logo small
          const WaslaLogoFull(size: 28),
          const SizedBox(height: 20),

          // Title
          Text(
            slide.title,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: AppColors.neutral900,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.desc,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.neutral500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
