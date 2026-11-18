import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/auction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(20), child: child)),
    );

void main() {
  testWidgets(
      '5 алхам 390px дээр overflow-гүй, +3 дарахад товчны шошго өөрчлөгдөнө',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var step = 1;
    int? sent;
    await tester.pumpWidget(StatefulBuilder(
      builder: (context, setState) => _host(BidControl(
        meId: 'u1',
        balance: 5,
        error: null,
        busy: false,
        currentPrice: 1000,
        step: step,
        onStep: (v) => setState(() => step = v),
        onBid: () => sent = step,
        onLogin: () {},
        onTopUp: () {},
      )),
    ));

    for (final v in [1, 2, 3, 4, 5]) {
      expect(find.text('+$v'), findsOneWidget);
    }
    expect(find.text('Үнэ илгээх · 1,001₮'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('+3'));
    await tester.pump();
    expect(find.text('Үнэ илгээх · 1,003₮'), findsOneWidget);

    await tester.tap(find.text('Үнэ илгээх · 1,003₮'));
    await tester.pump();
    expect(sent, 3);
  });

  testWidgets('зочинд зөвхөн "Нэвтэрч оролцох" товч', (tester) async {
    await tester.pumpWidget(_host(BidControl(
      meId: null,
      balance: 0,
      error: null,
      busy: false,
      onBid: () {},
      onLogin: () {},
      onTopUp: () {},
    )));
    expect(find.text('Нэвтэрч оролцох'), findsOneWidget);
    expect(find.text('+1'), findsNothing);
  });
}
