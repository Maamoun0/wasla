import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class AddPhotosScreen extends StatelessWidget {
  const AddPhotosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة صور الإعلان'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الخطوة 3 من 5', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      decoration: BoxDecoration(
                        color: WaslaTheme.primaryTealLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: WaslaTheme.primaryTeal),
                      ),
                      child: const Icon(Icons.add_a_photo, color: WaslaTheme.primaryTeal),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.image, color: Colors.grey[400]),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/post/location');
              },
              child: const Text('التالي: الموقع والسعر'),
            ),
          ],
        ),
      ),
    );
  }
}
