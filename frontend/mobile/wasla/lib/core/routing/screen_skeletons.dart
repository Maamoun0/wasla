import 'package:flutter/material.dart';
import '../theme/wasla_theme.dart';

// ── EXPLORE SUB-SCREENS ──

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نتائج البحث')),
    body: const Center(child: Text('هنا تظهر نتائج البحث المفلترة')),
  );
}

class MapViewScreen extends StatelessWidget {
  const MapViewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('عرض الخريطة')),
    body: const Center(child: Text('خريطة تفاعلية للإعلانات القريبة')),
  );
}

class PhotoViewerScreen extends StatelessWidget {
  final String adId;
  const PhotoViewerScreen({super.key, required this.adId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('معرض الصور'), backgroundColor: Colors.black),
    body: const Center(child: Text('عرض الصور بشاشة كاملة مع ميزة الزووم', style: TextStyle(color: Colors.white))),
  );
}

// ── SAVED SUB-SCREENS ──

class WatchlistResultsScreen extends StatelessWidget {
  final String id;
  const WatchlistResultsScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نتائج البحث المحفوظ')),
    body: Center(child: Text('عرض نتائج البحث المحفوظ ذو المعرف: $id')),
  );
}

// ── PROFILE SUB-SCREENS ──

class MyAdsScreen extends StatelessWidget {
  const MyAdsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إعلاناتي')),
    body: const Center(child: Text('إدارة إعلاناتك النشطة والمعلقة والمرفوضة')),
  );
}

class AdPerformanceScreen extends StatelessWidget {
  final String id;
  const AdPerformanceScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('أداء الإعلان')),
    body: Center(child: Text('تحليلات وإحصائيات الإعلان ذو المعرف: $id')),
  );
}

class BoostAdScreen extends StatelessWidget {
  final String id;
  const BoostAdScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تعزيز الإعلان (Boost)')),
    body: Center(child: Text('اختر باقة تعزيز الإعلان للرقم: $id')),
  );
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('خطط الاشتراك')),
    body: const Center(child: Text('اختر باقة الاشتراك الأنسب لأعمالك')),
  );
}

class MyReviewsScreen extends StatelessWidget {
  const MyReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تقييماتي')),
    body: const Center(child: Text('عرض وإدارة التقييمات والرد عليها')),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات')),
    body: const Center(child: Text('خيارات الحساب والخصوصية والإشعارات')),
  );
}

class SellerProfileScreen extends StatelessWidget {
  final String id;
  const SellerProfileScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ملف المعلن')),
    body: Center(child: Text('الملف الشخصي العام للمعلن ذو المعرف: $id')),
  );
}

// ── PAYMENT SUB-SCREENS ──

class PaymentWebViewScreen extends StatelessWidget {
  const PaymentWebViewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بوابة الدفع الآمن (Paymob)')),
    body: const Center(child: Text('WebView لإتمام عملية الدفع بأمان')),
  );
}

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: WaslaTheme.successGreen),
          const SizedBox(height: 16),
          const Text('تمت عملية الدفع بنجاح!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('العودة للتطبيق'),
          )
        ],
      ),
    ),
  );
}

// ── ADMIN SUB-SCREENS ──

class ModeratorDashboard extends StatelessWidget {
  const ModeratorDashboard({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('لوحة تحكم المشرف')),
    body: const Center(child: Text('مراجعة الإعلانات المعلقة والبلاغات لضمان أمان المنصة')),
  );
}
