import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _client;

  SupabaseChatRepository(this._client);

  @override
  Future<List<Map<String, dynamic>>> getConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // جلب المحادثات التي يكون فيها المستخدم الحالي هو البائع أو المشتري
    final response = await _client
        .from('conversations')
        .select('*, ads(title, price), buyer:users!buyer_id(full_name, avatar_url), seller:users!seller_id(full_name, avatar_url), messages(content, created_at, sender_id, is_read)')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId');

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> sendMessage(String conversationId, String content) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول لإرسال رسالة');

    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content.trim(),
    });
  }

  @override
  Future<String> createConversation(String adId, String sellerId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('يجب تسجيل الدخول لبدء محادثة');
    if (userId == sellerId) throw Exception('لا يمكنك بدء محادثة مع نفسك');

    // التحقق أولاً من وجود محادثة سابقة لنفس الإعلان وبنفس المشتري لتفادي التكرار
    final existing = await _client
        .from('conversations')
        .select('id')
        .eq('ad_id', adId)
        .eq('buyer_id', userId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final response = await _client.from('conversations').insert({
      'ad_id': adId,
      'buyer_id': userId,
      'seller_id': sellerId,
    }).select('id').single();

    return response['id'] as String;
  }

  @override
  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }
}
