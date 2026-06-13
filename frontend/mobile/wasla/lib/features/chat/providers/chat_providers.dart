import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/repositories/supabase_chat_repository.dart';
import '../domain/repositories/chat_repository.dart';

/// موفر مستودع المحادثات
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseChatRepository(client);
});

/// موفر قائمة المحادثات النشطة للمستخدم
final conversationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  // نراقب حالة الدخول والخروج لتحديث القائمة فوراً
  ref.watch(currentUserProvider);
  return repo.getConversations();
});

/// موفر بث الرسائل الحية لمحادثة معينة بالمعرف الخاص بها
final messagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, conversationId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.streamMessages(conversationId);
});
