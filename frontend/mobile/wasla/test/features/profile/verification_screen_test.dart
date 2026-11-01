import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:wasla/features/profile/screens/verification_screen.dart';

import '../../helpers/fake_backend.dart';
import '../../helpers/fake_picker.dart';

const _validId = '29505280101234';

Future<void> _fillAndCapture(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'محمد أحمد علي');
  await tester.enterText(find.byType(TextFormField).at(1), _validId);
  await tester.pumpAndSettle();
  for (var step = 0; step < 4; step++) {
    if (step > 0) {
      await tester.tap(find.text('التقط الآن'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
  }
}

void main() {
  late FakeImagePicker picker;
  setUp(() => picker = FakeImagePicker.install());

  testWidgets('walks data, card front, card back and selfie, then submits all three photos', (tester) async {
    final backend = FakeBackend({'/functions/v1/submit-kyc-request': (_) => {'success': true}});
    await pumpScreen(tester, const VerificationScreen(), backend: backend);

    expect(find.text('البيانات الشخصية'), findsWidgets);
    await _fillAndCapture(tester);

    // Photos come from the camera only, the selfie from the front one.
    expect(picker.picks, everyElement(ImageSource.camera));
    expect(picker.preferredCameras, [CameraDevice.rear, CameraDevice.rear, CameraDevice.front]);

    expect(find.text('مراجعة وتأكيد طلب التوثيق'), findsOneWidget);
    expect(find.text('الاسم: محمد أحمد علي'), findsOneWidget);
    expect(find.text('الرقم القومي: $_validId'), findsOneWidget);

    backend.routes['/rest/v1/user_verifications'] = (_) => [
          {'id': 'v1', 'status': 'pending', 'created_at': '2026-11-01T10:00:00Z', 'national_id_last4': '1234'}
        ];
    await tapAndWait(tester, find.text('إرسال طلب التوثيق'));

    final body = backend.lastBody('/functions/v1/submit-kyc-request') as Map;
    expect(body['full_name'], 'محمد أحمد علي');
    expect(body['national_id'], _validId);
    for (final key in ['front_image', 'back_image', 'selfie_image']) {
      expect(body[key], isNotEmpty, reason: key);
    }
    expect(find.text('طلبك قيد المراجعة حالياً'), findsOneWidget);
  });

  testWidgets('"next" stays off until the step is complete', (tester) async {
    await pumpScreen(tester, const VerificationScreen(), backend: FakeBackend());

    ElevatedButton next() => tester.widget<ElevatedButton>(find.ancestor(of: find.text('التالي'), matching: find.byType(ElevatedButton)));
    expect(next().onPressed, isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'محمد أحمد علي');
    await tester.enterText(find.byType(TextFormField).at(1), _validId);
    await tester.pumpAndSettle();
    expect(next().onPressed, isNotNull);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(next().onPressed, isNull, reason: 'no card photo yet');
    await tester.tap(find.text('التقط الآن'));
    await tester.pumpAndSettle();
    expect(next().onPressed, isNotNull);

    await tester.tap(find.text('السابق'));
    await tester.pumpAndSettle();
    expect(find.text('البيانات الشخصية'), findsWidgets);
  });

  testWidgets('a refused request shows the server message', (tester) async {
    final backend = FakeBackend({
      '/functions/v1/submit-kyc-request': (_) => const Failure(409, 'البطاقة دي مستخدمة في حساب تاني'),
    });
    await pumpScreen(tester, const VerificationScreen(), backend: backend);
    await _fillAndCapture(tester);
    await tapAndWait(tester, find.text('إرسال طلب التوثيق'));

    expect(find.text('البطاقة دي مستخدمة في حساب تاني'), findsWidgets);
  });

  testWidgets('a rejected request shows the reason and lets the user start again', (tester) async {
    final backend = FakeBackend({
      '/rest/v1/user_verifications': (_) => [
            {'id': 'v1', 'status': 'rejected', 'rejection_reason': 'الصورة مش واضحة', 'created_at': '2026-10-01T10:00:00Z'}
          ],
    });
    await pumpScreen(tester, const VerificationScreen(), backend: backend);

    expect(find.text('تم رفض طلب التوثيق'), findsOneWidget);
    expect(find.textContaining('سبب الرفض: الصورة مش واضحة'), findsOneWidget);
    await tester.tap(find.text('تقديم طلب جديد'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('an approved request shows the verified state', (tester) async {
    final backend = FakeBackend({
      '/rest/v1/user_verifications': (_) => [
            {'id': 'v1', 'status': 'approved', 'created_at': '2026-10-01T10:00:00Z'}
          ],
    });
    await pumpScreen(tester, const VerificationScreen(), backend: backend);
    expect(find.text('تم توثيق الحساب بنجاح'), findsOneWidget);
  });
}
