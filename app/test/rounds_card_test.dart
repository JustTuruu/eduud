// Round-той хугацааны карт: 11 шатыг overflow-гүй зурж, одоогийн шатыг тодруулах,
// анхны үнэ ирээгүй үед тоолуур харуулахгүй байхыг шалгана.
import 'package:eduud/core/models.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/auction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _secs = [3600, 2700, 1800, 900, 600, 300, 120, 60, 30, 10, 5];

List<AuctionRound> _rounds(DateTime start) {
  var t = start;
  return [
    for (final s in _secs)
      () {
        final r = AuctionRound(
            startsAt: t, endsAt: t.add(Duration(seconds: s)), durationSec: s);
        t = t.add(Duration(seconds: s));
        return r;
      }()
  ];
}

AuctionDetail _detail(List<AuctionRound> rounds, int bidCount) {
  final now = DateTime.now();
  return AuctionDetail(
    id: 'a1',
    title: 'Тест',
    description: '',
    images: const [],
    currentPrice: 1000,
    increment: 50,
    bidCount: bidCount,
    startsAt: rounds.first.startsAt,
    endsAt: bidCount == 0
        ? rounds.last.endsAt
        : now.add(const Duration(minutes: 4)),
    status: 'live',
    bids: const [],
    serverTime: now.millisecondsSinceEpoch,
    rounds: rounds,
  );
}

Future<void> _pump(WidgetTester tester, AuctionDetail a) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: SingleChildScrollView(
        child: TimingCard(auction: a, offsetMs: 0, onFinished: () {}),
      ),
    ),
  ));
}

void main() {
  testWidgets('11 round overflow-гүй, одоогийн шат тодорно', (tester) async {
    // Одоо = 5-р шатны дунд (3600+2700+1800+900 = 9000с-ын дараа)
    final start = DateTime.now().subtract(const Duration(seconds: 9100));
    await _pump(tester, _detail(_rounds(start), 3));
    expect(tester.takeException(), isNull);
    for (var i = 1; i <= 11; i++) {
      expect(find.text('Round $i'), findsOneWidget);
    }
    final cur = tester.widget<Text>(find.text('Round 5'));
    expect(cur.style!.fontWeight, FontWeight.w700);
    final other = tester.widget<Text>(find.text('Round 4'));
    expect(other.style!.fontWeight, FontWeight.w400);
    expect(find.text('Анхны үнэ хүлээж байна'), findsNothing);
    expect(find.textContaining('Round 5 · 10 мин'), findsOneWidget);
  });

  testWidgets('bidCount == 0 үед тоолуургүй', (tester) async {
    final start = DateTime.now().subtract(const Duration(seconds: 100));
    await _pump(tester, _detail(_rounds(start), 0));
    expect(tester.takeException(), isNull);
    expect(find.text('Анхны үнэ хүлээж байна'), findsOneWidget);
    expect(find.text('Үнэ ирмэгц 1 цаг тоолж эхэлнэ'), findsOneWidget);
    expect(find.text('Хамгийн оройдоо'), findsOneWidget);
  });
}
