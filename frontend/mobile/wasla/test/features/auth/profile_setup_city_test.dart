import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/core/constants/app_constants.dart';
import 'package:wasla/features/auth/screens/profile_setup_screen.dart';
import 'package:wasla/shared/providers/locations_provider.dart';

const _governorates = [
  {'id': 1, 'name_ar': 'القاهرة'},
  {'id': 2, 'name_ar': 'الإسكندرية'},
];
const _cities = {
  1: [
    {'id': 11, 'name_ar': 'مدينة نصر'},
    {'id': 12, 'name_ar': 'المعادي'},
  ],
  2: [
    {'id': 21, 'name_ar': 'سموحة'},
  ],
};

Future<void> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      governoratesProvider.overrideWith((ref) async => _governorates),
      citiesProvider.overrideWith((ref, govId) async => _cities[govId] ?? const []),
    ],
    child: const MaterialApp(home: ProfileSetupScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String option) async {
  await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saving without a governorate and city shows the required errors', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextFormField).first, 'محمد أحمد');
    await tester.tap(find.text('ابدأ الاستخدام'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errorRequired), findsNWidgets(2));
  });

  testWidgets('cities follow the chosen governorate, and changing it clears the city', (tester) async {
    await _pump(tester);

    await _choose(tester, 'المحافظة', 'القاهرة');
    await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, 'المدينة / الحي'));
    await tester.pumpAndSettle();
    expect(find.text('مدينة نصر'), findsWidgets);
    expect(find.text('سموحة'), findsNothing);
    await tester.tap(find.text('المعادي').last);
    await tester.pumpAndSettle();
    expect(find.text('المعادي'), findsOneWidget);

    await _choose(tester, 'المحافظة', 'الإسكندرية');
    expect(find.text('المعادي'), findsNothing, reason: 'a city from the old governorate is cleared');
    await _choose(tester, 'المدينة / الحي', 'سموحة');
    expect(find.text('سموحة'), findsOneWidget);
  });
}
