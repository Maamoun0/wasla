import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// The in-app notification center.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  /// The newest [limit] notifications, live.
  Stream<List<Map<String, dynamic>>> watch(String userId, {required int limit}) => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => rows.cast<Map<String, dynamic>>());

  Future<int> unreadCount() => _client.rpc<int>('unread_notifications_count');

  /// Null marks all of them.
  Future<void> markRead(List<String>? ids) => _client.rpc('mark_notifications_read', params: {'p_ids': ids});
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(supabaseClientProvider)));
