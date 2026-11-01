import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_client_provider.dart';

/// Publishing an ad: its photos, its category's fields, the plan's limits and
/// the create-ad function.
class PostAdRepository {
  PostAdRepository(this._client);

  final SupabaseClient _client;

  /// Uploads one photo and returns its public URL. Paths are
  /// `{userId}/{draftId}/{imageId}.jpg`: storage policies only allow writes
  /// inside the caller's own `{userId}/` folder.
  Future<String> uploadImage(String path, File file) async {
    await _client.storage.from('ads').upload(
          path,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('ads').getPublicUrl(path);
  }

  Future<void> removeImage(String path) => _client.storage.from('ads').remove([path]);

  /// create-ad's answer. Non-2xx answers throw FunctionException.
  Future<Object?> publish(Map<String, dynamic> body) async =>
      (await _client.functions.invoke('create-ad', body: body)).data;

  /// The parent category's shared fields followed by the subcategory's own.
  Future<List<Map<String, dynamic>>> categoryFields(int categoryId) async => List<Map<String, dynamic>>.from(
      await _client.rpc('get_category_fields', params: {'p_category_id': categoryId}) as List);

  /// The caller's plan limits and usage.
  Future<Object?> planUsage() => _client.rpc('my_plan_usage');
}

final postAdRepositoryProvider = Provider<PostAdRepository>((ref) => PostAdRepository(ref.watch(supabaseClientProvider)));
