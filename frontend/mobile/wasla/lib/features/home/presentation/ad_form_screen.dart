import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdFormScreen extends StatefulWidget {
  const AdFormScreen({super.key});

  @override
  State<AdFormScreen> createState() => _AdFormScreenState();
}

class _AdFormScreenState extends State<AdFormScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإعلان'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الخطوة 2 من 5', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان الإعلان (مثال: شقة للبيع بالرحاب)',
                hintText: 'اكتب عنواناً واضحاً وموجزاً',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'شرح وتفاصيل الإعلان',
                hintText: 'اكتب مواصفات الخدمة أو السلعة وعيوبها ومميزاتها بكل صدق وأمانة',
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                context.push('/post/photos');
              },
              child: const Text('التالي: إضافة صور'),
            ),
          ],
        ),
      ),
    );
  }
}
