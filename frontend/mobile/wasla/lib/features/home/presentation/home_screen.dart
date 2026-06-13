import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('وصلة'),
        leading: const Icon(Icons.handshake_rounded, color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.push('/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // بنر ترويجي جذاب
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [WaslaTheme.primaryTeal, WaslaTheme.primaryTealDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: WaslaTheme.primaryTeal.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'وثّق هويتك الآن مجاناً! 🛡️',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'احصل على شارة موثق الذهبية لزيادة مبيعاتك بنسبة 200% وجذب المزيد من المشترين بأمان كامل.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.push('/profile/verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WaslaTheme.secondaryGold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('ابدأ التوثيق الآن'),
                  ),
                ],
              ),
            ),
          ),

          // قسم التصنيفات
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الأقسام الرئيسية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: WaslaTheme.primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCategoryItem(context, '🚗', 'سيارات', '/explore'),
                      _buildCategoryItem(context, '🏠', 'عقارات', '/explore'),
                      _buildCategoryItem(context, '🛠️', 'خدمات', '/explore'),
                      _buildCategoryItem(context, '💼', 'وظائف', '/explore'),
                      _buildCategoryItem(context, '📱', 'أجهزة', '/explore'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // قسم إعلانات مميزة قريبة منك
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'إعلانات مميزة قريبة منك',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: WaslaTheme.primaryTeal,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/explore'),
                    child: const Text(
                      'عرض الكل',
                      style: TextStyle(color: WaslaTheme.secondaryGold, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // قائمة الإعلانات المميزة الافتراضية
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final List<Map<String, String>> sampleAds = [
                    {
                      'title': 'سيارة هيونداي إلنترا 2021 فبريكا بالكامل',
                      'price': '850,000 ج.م',
                      'location': 'القاهرة، مصر الجديدة',
                      'time': 'منذ ساعة',
                      'badge': 'مميز'
                    },
                    {
                      'title': 'مطلوب فني تكييف وصيانة فورية لشقة سكنية',
                      'price': '350 ج.م / ساعة',
                      'location': 'الجيزة، الشيخ زايد',
                      'time': 'منذ 3 ساعات',
                      'badge': 'عاجل'
                    },
                    {
                      'title': 'شقة لقطة للبيع بالرحاب 150م بتسهيلات',
                      'price': '4,200,000 ج.م',
                      'location': 'القاهرة، التجمع الخامس',
                      'time': 'منذ 5 ساعات',
                      'badge': 'مميز'
                    }
                  ];

                  final ad = sampleAds[index];

                  return Card(
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFEAE4DA)),
                    ),
                    child: InkWell(
                      onTap: () {
                        context.push('/ad/sample_id_$index');
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ad['badge'] == 'عاجل'
                                              ? WaslaTheme.errorRed.withOpacity(0.1)
                                              : WaslaTheme.secondaryGold.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          ad['badge']!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: ad['badge'] == 'عاجل'
                                                ? WaslaTheme.errorRed
                                                : WaslaTheme.secondaryGoldDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ad['title']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ad['price']!,
                                    style: const TextStyle(
                                        color: WaslaTheme.primaryTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 12, color: WaslaTheme.textMuted),
                                      const SizedBox(width: 2),
                                      Text(
                                        ad['location']!,
                                        style: const TextStyle(fontSize: 10, color: WaslaTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: 3,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, String icon, String title, String route) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: WaslaTheme.primaryTealLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              icon,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: WaslaTheme.textDark),
          ),
        ],
      ),
    );
  }
}
