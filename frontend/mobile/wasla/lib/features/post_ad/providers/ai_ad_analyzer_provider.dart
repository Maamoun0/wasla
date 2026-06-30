import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'ai_ad_analyzer_provider.g.dart';

@riverpod
class AiAdAnalyzer extends _$AiAdAnalyzer {
  @override
  bool build() => false; // returns true while analyzing

  Future<Map<String, dynamic>?> analyzeImage(String imageUrl, String categoryName) async {
    state = true;
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'analyze-ad-image',
        body: {
          'image_url': imageUrl,
          'category_name': categoryName,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('AI Analysis error: $e');
    } finally {
      state = false;
    }
    return null;
  }
}
