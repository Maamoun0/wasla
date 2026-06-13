import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/wasla_theme.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/chat_providers.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsyncValue = ref.watch(conversationsProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الرسائل والمحادثات'),
      ),
      body: conversationsAsyncValue.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: WaslaTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محادثات نشطة حالياً',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: WaslaTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تصفح الإعلانات وتواصل مع البائعين لبدء المحادثة',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: WaslaTheme.textMuted,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                
                // تحديد بيانات الطرف الآخر في المحادثة
                final bool isCurrentUserBuyer = currentUser?.id == conversation['buyer_id'];
                final otherParty = isCurrentUserBuyer ? conversation['seller'] : conversation['buyer'];
                final adInfo = conversation['ads'];
                final messages = conversation['messages'] as List<dynamic>? ?? [];
                
                // جلب الرسالة الأخيرة
                final lastMessage = messages.isNotEmpty ? messages.first : null;
                final lastMessageText = lastMessage != null ? lastMessage['content'] as String : 'بدء المحادثة...';
                final lastMessageTime = lastMessage != null 
                    ? DateTime.parse(lastMessage['created_at']) 
                    : DateTime.parse(conversation['created_at']);
                final bool isUnread = lastMessage != null 
                    ? !(lastMessage['is_read'] as bool) && lastMessage['sender_id'] != currentUser?.id
                    : false;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: WaslaTheme.primaryTealLight,
                    backgroundImage: otherParty?['avatar_url'] != null 
                        ? NetworkImage(otherParty!['avatar_url'] as String) 
                        : null,
                    child: otherParty?['avatar_url'] == null 
                        ? const Icon(Icons.person, color: WaslaTheme.primaryTeal) 
                        : null,
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        otherParty?['full_name'] as String? ?? 'مستخدم وصلة',
                        style: TextStyle(
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        intl.DateFormat('hh:mm a').format(lastMessageTime.toLocal()),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUnread ? WaslaTheme.primaryTeal : WaslaTheme.textMuted,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessageText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isUnread ? WaslaTheme.textDark : WaslaTheme.textMuted,
                              fontSize: 13,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (adInfo != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: WaslaTheme.primaryTealLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              adInfo['title'] as String,
                              maxLines: 1,
                              style: const TextStyle(fontSize: 10, color: WaslaTheme.primaryTeal, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: () {
                    context.push('/chat/${conversation['id']}');
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: WaslaTheme.errorRed),
              const SizedBox(height: 16),
              const Text('حدث خطأ أثناء تحميل الرسائل'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.refresh(conversationsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
