import 'package:flutter/material.dart';
import '../../../core/theme/wasla_theme.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> notifications = [
      {
        'title': 'تم توثيق حسابك بنجاح!',
        'body': 'تهانينا، لقد تمت مراجعة بطاقة الرقم القومي الخاصة بك وحسابك الآن موثق بالشارة الذهبية.',
        'time': 'منذ ساعة',
        'isRead': 'false',
      },
      {
        'title': 'إعلان جديد يطابق تنبيهك',
        'body': 'هناك إعلان جديد مضاف حديثاً يطابق تنبيه البحث المحفوظ "شقة للبيع بالمهندسين".',
        'time': 'منذ يوم',
        'isRead': 'true',
      },
      {
        'title': 'تفعيل الإعلان المعلق',
        'body': 'تمت الموافقة على إعلانك "سيارة كيا سيراتو للبيع" وهو الآن نشط ويظهر للجميع.',
        'time': 'منذ يومين',
        'isRead': 'true',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          final isUnread = notif['isRead'] == 'false';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: isUnread ? WaslaTheme.primaryTealLight : Colors.grey[100],
              child: Icon(
                isUnread ? Icons.notifications_active : Icons.notifications_outlined,
                color: isUnread ? WaslaTheme.primaryTeal : Colors.grey[400],
              ),
            ),
            title: Text(
              notif['title']!,
              style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  notif['body']!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  notif['time']!,
                  style: const TextStyle(fontSize: 11, color: WaslaTheme.textMuted),
                ),
              ],
            ),
            tileColor: isUnread ? WaslaTheme.primaryTealLight.withOpacity(0.2) : null,
          );
        },
      ),
    );
  }
}
