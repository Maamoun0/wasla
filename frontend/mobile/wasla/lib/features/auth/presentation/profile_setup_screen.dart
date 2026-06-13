import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/wasla_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _selectedCity;

  final List<String> _cities = [
    'القاهرة',
    'الجيزة',
    'الإسكندرية',
    'القليوبية',
    'الدقهلية',
    'الشرقية',
    'المنوفية',
    'الغربية',
    'البحيرة',
    'الفيوم',
  ];

  void _saveProfile() {
    if (_nameController.text.trim().isNotEmpty && _selectedCity != null) {
      // حفظ البيانات محلياً أو في سوبابيس (سيتم ربطها بالمستودع لاحقاً)
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم واختيار المدينة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الملف الشخصي'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: WaslaTheme.primaryTealLight,
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: WaslaTheme.primaryTeal,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: WaslaTheme.secondaryGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'أهلاً بك! دعنا نتعرف عليك',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: WaslaTheme.primaryTeal,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'المدينة',
                prefixIcon: Icon(Icons.location_city),
              ),
              items: _cities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCity = val;
                });
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('بدأ استخدام وصلة'),
            ),
          ],
        ),
      ),
    );
  }
}
