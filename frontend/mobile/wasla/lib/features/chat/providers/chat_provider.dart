import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_models.dart';

part 'chat_provider.g.dart';

@riverpod
class ChatController extends _$ChatController {
  late final SupabaseClient _supabase;

  @override
  FutureOr<List<Conversation>> build() async {
    _supabase = Supabase.instance.client;
    return _fetchConversations();
  }

  Future<List<Conversation>> _fetchConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('conversations')
        .select('''
          *,
          ads:ad_id(title),
          buyer:buyer_id(full_name, avatar_url),
          seller:seller_id(full_name, avatar_url)
        ''')
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('last_message_at', ascending: false);

    return (response as List).map((json) {
      final isBuyer = json['buyer_id'] == userId;
      final otherUser = isBuyer ? json['seller'] : json['buyer'];
      
      return Conversation.fromJson({
        ...json,
        'ad_title': json['ads']['title'],
        'other_user_full_name': otherUser['full_name'],
        'other_user_avatar_url': otherUser['avatar_url'],
      });
    }).toList();
  }

  Future<void> sendMessage(String conversationId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
    });
  }

  void subscribeToMessages(String conversationId, Function(ChatMessage) onMessage) {
    _supabase
        .channel('public:messages:conversation_id=eq.$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onMessage(ChatMessage.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }
}
