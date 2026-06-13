import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'icon': '🔍',
      'title': 'ابحث بذكاء وأمان',
      'desc': 'تصفح آلاف الإعلانات والخدمات القريبة منك في مصر مع التأكد من موثوقية البائعين.',
    },
    {
      'icon': '➕',
      'title': 'انشر إعلاناتك بسهولة',
      'desc': 'أضف صور وتفاصيل إعلانك أو خدمتك في دقائق معدودة وابدأ في استقبال العروض.',
    },
    {
      'icon': '🛡️',
      'title': 'تواصل آمن وموثق',
      'desc': 'نظام توثيق صارم للهوية وتقييمات حقيقية لحماية معاملتك من التلاعب والسرقة.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'تخطي',
                  style: TextStyle(color: WaslaTheme.primaryTeal, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          slide['icon']!,
                          style: const TextStyle(fontSize: 80),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          slide['title']!,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: WaslaTheme.primaryTeal,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['desc']!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: WaslaTheme.textMuted,
                                height: 1.6,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: _currentPage == index ? 24.0 : 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? WaslaTheme.primaryTeal : WaslaTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentPage == _slides.length - 1) {
                    context.go('/login');
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  }
                },
                child: Text(
                  _currentPage == _slides.length - 1 ? 'ابدأ الآن' : 'التالي',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
