import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/features/auth/screens/auth_screen.dart';
import 'package:wasla/features/legal/legal_provider.dart';
import 'package:wasla/features/legal/legal_screen.dart';

const _terms = LegalDocument(kind: LegalKind.terms, version: 3, body: 'نص الشروط المراجَع');
const _privacy = LegalDocument(kind: LegalKind.privacy, version: 2, body: 'نص الخصوصية');

void main() {
  group('LegalDocument.fromConfig', () {
    test('reads version, text and link as stored in app_configs', () {
      final d = LegalDocument.fromConfig(LegalKind.terms, {'version': 4, 'body': 'x', 'url': 'https://wasla.example/terms'});
      expect([d.version, d.body, d.url.toString()], [4, 'x', 'https://wasla.example/terms']);
    });

    test('only web links are opened; missing values fall back to the placeholder version 0', () {
      expect(LegalDocument.fromConfig(LegalKind.privacy, {'url': 'javascript:alert(1)'}).url, isNull);
      expect(LegalDocument.fromConfig(LegalKind.privacy, null).version, 0);
    });
  });

  testWidgets('the screen shows the published text with its version', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [legalDocumentsProvider.overrideWith((ref) async => {LegalKind.terms: _terms, LegalKind.privacy: _privacy})],
      child: const MaterialApp(home: LegalScreen(kind: LegalKind.terms)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('نص الشروط المراجَع'), findsOneWidget);
    expect(find.text('الإصدار 3'), findsOneWidget);
  });

  testWidgets('the consent dialog records the exact versions it shows', (tester) async {
    final accepted = <(int, int)>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        legalAcceptorProvider.overrideWith((ref) => (t, p) async {
              accepted.add((t, p));
              return true;
            }),
      ],
      child: const MaterialApp(home: Scaffold(body: LegalConsentDialog(terms: _terms, privacy: _privacy))),
    ));
    await tester.tap(find.text('أوافق'));
    await tester.pumpAndSettle();
    expect(accepted, [(3, 2)]);
  });

  testWidgets('sign-up consent is not pre-ticked', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: AuthScreen())));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });
}
