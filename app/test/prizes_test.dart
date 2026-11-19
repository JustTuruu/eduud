// Нэмэлт шагнал: parse, currentPlacements, админ форм валидаци, Шагнал карт.
import 'package:eduud/core/models.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/admin/admin_auction_form.dart';
import 'package:eduud/features/auction/auction_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BidItem _bid(String id, String user) => BidItem(
    id: id,
    price: 100,
    createdAt: DateTime(2026),
    user: Bidder(id: user, name: 'N-$user'));

void main() {
  test('currentPlacements: давхардсан оролцогчийг алгасч 3-г авна', () {
    final p = currentPlacements([
      _bid('1', 'a'),
      _bid('2', 'a'),
      _bid('3', 'b'),
      _bid('4', 'a'),
      _bid('5', 'c'),
      _bid('6', 'd')
    ]);
    expect(p.map((e) => e.user.id), ['a', 'b', 'c']);
    expect(p.map((e) => e.place), [1, 2, 3]);
    expect(currentPlacements([]), isEmpty);
    expect(currentPlacements([_bid('1', 'a')]).length, 1);
  });

  test('prizes parse: null-safe, label, placements', () {
    expect(parsePrizes(null), isEmpty);
    final prizes = parsePrizes([
      {'place': 3, 'kind': 'item', 'tokens': 0, 'title': 'AirPods'},
      {'place': 2, 'kind': 'tokens', 'tokens': 200, 'title': null},
    ]);
    expect(prizes.map((e) => e.label), ['200 эрх', 'AirPods']);
    final pl = parsePlacements([
      {
        'place': 2,
        'user': {'id': 'u', 'name': 'Бат'},
        'prize': {'kind': 'tokens', 'tokens': 200, 'title': null}
      },
      {
        'place': 1,
        'user': {'id': 'w', 'name': 'Дорж'},
        'prize': null
      },
    ]);
    expect(pl.first.place, 1);
    expect(pl.first.prize, isNull);
    expect(pl.last.prize!.label, '200 эрх');
    expect(
        prizeAwardedMessage(
            {'place': 2, 'kind': 'tokens', 'tokens': 200, 'title': null}),
        'Та 2-р байр эзэлж 200 эрх авлаа');
  });

  test('OrderItem: 0₮ шагналын захиалга төлбөр шаардахгүй', () {
    OrderItem o(int price, [int? place]) => OrderItem.fromJson({
          'id': 'o',
          'auctionId': 'a',
          'finalPrice': price,
          'payDeadline': '2026-01-01T00:00:00Z',
          'status': 'pending',
          'auction': <String, dynamic>{},
          if (place != null) 'prizePlace': place,
        });
    expect(o(0, 2).needsPayment, isFalse);
    expect(o(0, 2).isPrize, isTrue);
    expect(o(500).needsPayment, isTrue);
  });

  test('шагналын валидаци', () {
    expect(validatePrizeInput(2, 'tokens', '200'), isNull);
    expect(validatePrizeInput(2, 'tokens', '0'), isNotNull);
    expect(validatePrizeInput(2, 'tokens', '100001'), isNotNull);
    expect(validatePrizeInput(2, 'tokens', 'abc'), isNotNull);
    expect(validatePrizeInput(3, 'item', ' '), isNotNull);
    expect(validatePrizeInput(3, 'item', 'x' * 121), isNotNull);
    expect(validatePrizeInput(3, 'item', 'AirPods'), isNull);

    final a = PrizeDraft(2, enabled: true)..value.text = '200';
    final b = PrizeDraft(3, enabled: true, kind: 'item')
      ..value.text = 'AirPods';
    final c = PrizeDraft(3);
    final (ok, e1) = buildPrizes([a, b]);
    expect(e1, isNull);
    expect(ok, [
      {'place': 2, 'kind': 'tokens', 'tokens': 200},
      {'place': 3, 'kind': 'item', 'title': 'AirPods'},
    ]);
    expect(buildPrizes([c]).$1, isEmpty);
    final bad = PrizeDraft(2, enabled: true);
    expect(buildPrizes([bad]).$2, isNotNull);
  });

  testWidgets('Шагнал карт: байр, шагнал, эзэн, "Та"', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: PrizesCard(
          mainTitle: 'iPhone 15',
          prizes: const [
            AuctionPrize(place: 2, kind: 'tokens', tokens: 200),
            AuctionPrize(place: 3, kind: 'item', title: 'AirPods'),
          ],
          placements: [
            AuctionPlacement(place: 1, user: Bidder(id: 'x', name: 'Дорж')),
            AuctionPlacement(place: 2, user: Bidder(id: 'me', name: 'Бат')),
          ],
          meId: 'me',
          isFinal: true,
        ),
      ),
    ));
    expect(find.text('Шагнал'), findsOneWidget);
    expect(find.text('iPhone 15'), findsOneWidget);
    expect(find.text('200 эрх'), findsOneWidget);
    expect(find.text('AirPods'), findsOneWidget);
    expect(find.text('Дорж'), findsOneWidget);
    expect(find.text('Та'), findsOneWidget);
    expect(find.textContaining('3 өөр оролцогч'), findsOneWidget);
  });
}
