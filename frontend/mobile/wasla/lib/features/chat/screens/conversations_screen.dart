import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/chat_provider.dart';
import '../../../core/constants/app_colors.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(chatControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المحادثات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
      body: conversationsAsync.when(
        data: (conversations) => conversations.isEmpty
            ? const Center(child: Text('لا توجد محادثات حالياً', style: TextStyle(fontFamily: 'Cairo')))
            : ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: conversation.otherUserAvatarUrl != null
                          ? NetworkImage(conversation.otherUserAvatarUrl!)
                          : null,
                      child: conversation.otherUserAvatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      conversation.otherUserFullName ?? 'مستخدم Wasla',
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conversation.adTitle ?? '',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primary600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          conversation.lastMessagePreview ?? 'بدء المحادثة...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                    trailing: Text(
                      DateFormat.jm('ar').format(conversation.lastMessageAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    onTap: () => context.push('/chat/${conversation.id}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
      ),
    );
  }
}
