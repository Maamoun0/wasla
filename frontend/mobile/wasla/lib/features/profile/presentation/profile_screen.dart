import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: WaslaTheme.primaryTeal,
              padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 48, color: WaslaTheme.primaryTeal),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'أحمد مأمون',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: WaslaTheme.secondaryGold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '4.8 (مقياس الثقة)',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'حساب موثق',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFEAE4DA)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('إعلاناتي', '12'),
                      Container(width: 1, height: 30, color: const Color(0xFFEAE4DA)),
                      _buildStatItem('التقييمات', '45'),
                      Container(width: 1, height: 30, color: const Color(0xFFEAE4DA)),
                      _buildStatItem('المشاهدات', '340'),
                    ],
                  ),
                ),
              ),
            ),
            _buildMenuItem(
              icon: Icons.list_alt,
              title: 'إدارة إعلاناتي',
              onTap: () => context.push('/profile/my-ads'),
            ),
            _buildMenuItem(
              icon: Icons.reviews_outlined,
              title: 'تقييماتي وآراء العملاء',
              onTap: () => context.push('/profile/reviews'),
            ),
            _buildMenuItem(
              icon: Icons.card_membership,
              title: 'خطة الاشتراك الحالية',
              onTap: () => context.push('/profile/subscription'),
            ),
            _buildMenuItem(
              icon: Icons.shield_outlined,
              title: 'توثيق الهوية (KYC)',
              onTap: () => context.push('/profile/verify'),
            ),
            const Divider(height: 32, indent: 16, endIndent: 16),
            _buildMenuItem(
              icon: Icons.logout,
              title: 'تسجيل الخروج',
              textColor: WaslaTheme.errorRed,
              iconColor: WaslaTheme.errorRed,
              onTap: () {
                // سيتم ربطها بعملية خروج سوبابيس
                context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: WaslaTheme.primaryTeal),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: WaslaTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color textColor = WaslaTheme.textDark,
    Color iconColor = WaslaTheme.primaryTeal,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}
