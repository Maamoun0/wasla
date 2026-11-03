import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasla/shared/widgets/wasla_logo.dart';

const _ad = {
  'id': 'a1',
  'title': 'شقق للبيع - استعمال خفيف - التجمع الخامس، تشطيب سوبر لوكس قريبة من كل الخدمات',
  'price': 2500000,
  'price_type': 'fixed',
  'is_featured': true,
  'is_urgent': true,
  'cities': {'name_ar': 'التجمع الخامس'},
};

void main() {
  // The device journey test found the cards overflowing (24–57 px) in the
  // home grid on a phone once real ads were there.
  testWidgets('cards fit a phone-width grid and the featured row with long titles', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SizedBox(
            height: 220,
            child: ListView(scrollDirection: Axis.horizontal, children: const [SizedBox(width: 180, child: AdCard(ad: _ad))]),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              padding: const EdgeInsets.all(16),
              children: List.generate(4, (_) => const AdCard(ad: _ad)),
            ),
          ),
        ]),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AdCard), findsWidgets);
  });

  testWidgets('in a list the card keeps its full photo height', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ListView(children: const [AdCard(ad: _ad)]))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(AdCard)).height, greaterThan(160));
  });
}
