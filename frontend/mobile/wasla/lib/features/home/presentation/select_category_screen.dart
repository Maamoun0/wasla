import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectCategoryScreen extends StatelessWidget {
  const SelectCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> categories = [
      {'icon': '🏠', 'title': 'عقارات', 'slug': 'real-estate'},
      {'icon': '🚗', 'title': 'سيارات ومركبات', 'slug': 'vehicles'},
      {'icon': '🛠️', 'title': 'خدمات صيانة وحرف', 'slug': 'services'},
      {'icon': '💼', 'title': 'وظائف شاغرة', 'slug': 'jobs'},
      {'icon': '📱', 'title': 'أجهزة إلكترونية', 'slug': 'electronics'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إعلان - اختيار القسم'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFEAE4DA)),
            ),
            child: ListTile(
              leading: Text(cat['icon'] as String, style: const TextStyle(fontSize: 24)),
              title: Text(
                cat['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                context.push('/post/form');
              },
            ),
          );
        },
      ),
    );
  }
}
