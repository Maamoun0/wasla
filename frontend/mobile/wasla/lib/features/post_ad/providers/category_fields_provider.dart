import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/post_ad_repository.dart';

// The wizard stores the subcategory id. get_category_fields returns the
// parent category's shared fields followed by the subcategory's own; querying
// category_fields by the subcategory id alone missed the shared ones.
final categoryFieldsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>(
    (ref, categoryId) => ref.watch(postAdRepositoryProvider).categoryFields(categoryId));
