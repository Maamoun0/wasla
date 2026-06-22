import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

final categoryFieldsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, categoryId) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('category_fields')
      .select()
      .eq('category_id', categoryId)
      .order('sort_order', ascending: true);
  return List<Map<String, dynamic>>.from(response);
});
