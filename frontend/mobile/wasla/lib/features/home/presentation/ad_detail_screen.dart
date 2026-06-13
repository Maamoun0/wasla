import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class AdDetailScreen extends StatelessWidget {
  final String adId;
  const AdDetailScreen({super.key, required this.adId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإعلان'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image, size: 64, color: Colors.grey),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شقة مفروشة للإيجار بالمهندسين تشطيب سوبر لوكس',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '20,000 ج.م / شهرياً',
                    style: TextStyle(fontSize: 18, color: WaslaTheme.primaryTeal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: WaslaTheme.textMuted),
                      SizedBox(width: 4),
                      Text('الجيزة، المهندسين', style: TextStyle(color: WaslaTheme.textMuted)),
                      Spacer(),
                      Icon(Icons.access_time, size: 16, color: WaslaTheme.textMuted),
                      SizedBox(width: 4),
                      Text('منذ ساعتين', style: TextStyle(color: WaslaTheme.textMuted)),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text(
                    'تفاصيل العقار',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WaslaTheme.primaryTeal),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('المساحة', '120 متر مربع'),
                  _buildDetailRow('الغرف', '3 غرف نوم + 2 حمام'),
                  _buildDetailRow('الدور', 'الدور الثالث'),
                  const Divider(height: 32),
                  const Text(
                    'الوصف',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WaslaTheme.primaryTeal),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'شقة مفروشة بالكامل بموقع مميز جداً بالمهندسين بالقرب من جامعة الدول العربية، مكيفة بالكامل، إنترنت فايبر سريع، عمارة حديثة بها مصعد وحراسة 24 ساعة.',
                    style: TextStyle(height: 1.5),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'المعلن',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: WaslaTheme.primaryTeal),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 24,
                      backgroundColor: WaslaTheme.primaryTealLight,
                      child: Icon(Icons.person, color: WaslaTheme.primaryTeal),
                    ),
                    title: const Text('محمد أحمد', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Row(
                      children: [
                        Icon(Icons.star, color: WaslaTheme.secondaryGold, size: 14),
                        SizedBox(width: 4),
                        Text('4.9 (مقياس الثقة)', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: OutlinedButton(
                      onPressed: () {
                        context.push('/seller/123');
                      },
                      child: const Text('عرض الملف الشخصي'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // محاكاة الاتصال بالبائع أو الانتقال للشات
                  context.push('/chat/new?adId=$adId&sellerId=123');
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('دردشة داخلية'),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: WaslaTheme.primaryTealLight,
              child: IconButton(
                icon: const Icon(Icons.phone, color: WaslaTheme.primaryTeal),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFFDCFCE7),
              child: IconButton(
                icon: const Icon(Icons.message, color: Color(0xFF15803D)),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: WaslaTheme.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
