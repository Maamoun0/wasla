import 'package:flutter/material.dart';
import '../../../core/theme/wasla_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _isFrontUploaded = false;
  bool _isBackUploaded = false;
  bool _isSelfieUploaded = false;

  void _submitVerification() {
    if (_isFrontUploaded && _isBackUploaded && _isSelfieUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال مستندات التحقق للمراجعة بنجاح!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء رفع جميع المستندات المطلوبة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('توثيق الهوية (KYC)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security, size: 64, color: WaslaTheme.primaryTeal),
            const SizedBox(height: 16),
            Text(
              'توثيق حسابك بخطوات بسيطة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: WaslaTheme.primaryTeal,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'وفقاً لقوانين حماية البيانات المصرية ولتوفير بيئة بيع وشراء آمنة، يرجى رفع المستندات التالية لتأكيد هويتك وحصولك على شارة موثق.',
              style: TextStyle(color: WaslaTheme.textMuted, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildUploadCard(
              title: 'الوجه الأمامي للبطاقة الشخصية',
              isUploaded: _isFrontUploaded,
              onTap: () {
                setState(() {
                  _isFrontUploaded = true;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'الوجه الخلفي للبطاقة الشخصية',
              isUploaded: _isBackUploaded,
              onTap: () {
                setState(() {
                  _isBackUploaded = true;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildUploadCard(
              title: 'صورة شخصية (سيلفي) واضحة',
              isUploaded: _isSelfieUploaded,
              onTap: () {
                setState(() {
                  _isSelfieUploaded = true;
                });
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _submitVerification,
              child: const Text('إرسال طلب التوثيق'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required bool isUploaded,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUploaded ? WaslaTheme.primaryTeal : const Color(0xFFEAE4DA),
          width: isUploaded ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle : Icons.cloud_upload_outlined,
                color: isUploaded ? WaslaTheme.successGreen : WaslaTheme.primaryTeal,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isUploaded ? 'تم الرفع بنجاح' : 'اضغط للرفع من معرض الصور أو الكاميرا',
                      style: TextStyle(
                        fontSize: 12,
                        color: isUploaded ? WaslaTheme.successGreen : WaslaTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
