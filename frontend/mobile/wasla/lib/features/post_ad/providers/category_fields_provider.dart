import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

// The wizard stores the subcategory id. get_category_fields returns the
// parent category's shared fields followed by the subcategory's own; querying
// category_fields by the subcategory id alone missed the shared ones.
final categoryFieldsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, categoryId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.rpc('get_category_fields', params: {'p_category_id': categoryId});
  return List<Map<String, dynamic>>.from(response as List);
});
