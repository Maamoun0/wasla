import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LocationPriceScreen extends StatefulWidget {
  const LocationPriceScreen({super.key});

  @override
  State<LocationPriceScreen> createState() => _LocationPriceScreenState();
}

class _LocationPriceScreenState extends State<LocationPriceScreen> {
  final _priceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموقع والسعر'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('الخطوة 4 من 5', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر المطلوب (جنيه مصري)',
                suffixText: 'ج.م',
              ),
            ),
            const SizedBox(height: 24),
            const Text('تحديد الموقع الجغرافي', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, color: Colors.red),
                    SizedBox(width: 8),
                    Text('اضغط لتحديد الموقع على الخريطة'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                context.push('/post/preview');
              },
              child: const Text('التالي: معاينة الإعلان'),
            ),
          ],
        ),
      ),
    );
  }
}
