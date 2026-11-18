import 'package:eduud/core/models.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/auction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<BidItem> _bids(int n) => [
      for (var i = 0; i < n; i++)
        BidItem(
          id: 'b$i',
          price: 1000 + i,
          createdAt: DateTime(2020, 1, 2, 3, 4, 5),
          user: Bidder(id: 'u$i', name: 'Хэрэглэгч $i'),
        ),
    ];

Widget _host(int n) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: BidHistory(bids: _bids(n)),
        ),
      ),
    );

void main() {
  testWidgets('30 санал 390px: өндөр хязгаарлагдаж, дотроо гүйлгэгдэнэ',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(30));
    await tester.pumpAndSettle();

    final h = tester.getSize(find.byType(BidHistory)).height;
    expect(h, lessThanOrEqualTo(BidHistory.maxHeight));
    expect(find.text('01.02 03:04:05'), findsWidgets); // өнөөдөр биш → MM.dd
    expect(find.text('Хэрэглэгч 29'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('Хэрэглэгч 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('богино жагсаалтад хайрцаг агуулгаараа багтана', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(3));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BidHistory)).height,
        lessThan(BidHistory.maxHeight / 2));
  });
}
