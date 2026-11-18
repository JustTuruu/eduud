import 'package:eduud/core/models.dart';
import 'package:eduud/features/home/auction_timing.dart';
import 'package:eduud/features/requests/request_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatRemaining', () {
    expect(formatRemaining(const Duration(seconds: 65)), '01:05');
    expect(formatRemaining(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03');
    expect(formatRemaining(const Duration(seconds: -5)), '00:00');
  });

  test('formatRemainingMs', () {
    expect(formatRemainingMs(const Duration(milliseconds: 754)), '00:00.754');
    expect(
        formatRemainingMs(
            const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 45)),
        '1:02:03.045');
    expect(formatRemainingMs(const Duration(seconds: -5)), '00:00.000');
  });

  test('formatStartLabel', () {
    final now = DateTime(2026, 11, 17, 9);
    expect(formatStartLabel(DateTime(2026, 11, 17, 20), now), 'Өнөөдөр 20:00');
    expect(formatStartLabel(DateTime(2026, 11, 18, 20), now), 'Маргааш 20:00');
    expect(formatStartLabel(DateTime(2026, 11, 25, 8, 5), now),
        '11-р сарын 25 · 08:05');
  });

  test('formatDateTimeLabel', () {
    final now = DateTime(2026, 11, 17, 9);
    expect(
        formatDateTimeLabel(DateTime(2026, 11, 16, 14), now), 'Өчигдөр 14:00');
    expect(
        formatDateTimeLabel(DateTime(2026, 11, 17, 14), now), 'Өнөөдөр 14:00');
    expect(
        formatDateTimeLabel(DateTime(2026, 11, 18, 14), now), 'Маргааш 14:00');
    expect(formatDateTimeLabel(DateTime(2026, 11, 25, 8, 5), now),
        '11-р сарын 25 · 08:05');
  });

  test('inSoftClose', () {
    expect(inSoftClose(const Duration(seconds: 29), 30), true);
    expect(inSoftClose(const Duration(seconds: 30), 30), false);
    expect(inSoftClose(const Duration(seconds: 60), 30), false);
    expect(inSoftClose(Duration.zero, 30), false);
    expect(inSoftClose(const Duration(seconds: -1), 30), false);
    expect(inSoftClose(const Duration(seconds: 5), 0), false);
  });

  group('rounds', () {
    final base = DateTime.utc(2026, 11, 18, 10);
    AuctionRound r(int startMin, int endMin, int sec) => AuctionRound(
        startsAt: base.add(Duration(minutes: startMin)),
        endsAt: base.add(Duration(minutes: endMin)),
        durationSec: sec);
    final rounds = [r(0, 10, 600), r(10, 20, 300), r(30, 40, 60)];

    test('roundIndexAt', () {
      expect(roundIndexAt(const [], base), isNull);
      expect(roundIndexAt(rounds, base.subtract(const Duration(hours: 1))), 0);
      expect(roundIndexAt(rounds, base), 0);
      expect(roundIndexAt(rounds, base.add(const Duration(minutes: 10))), 1);
      // завсар: өмнөх шат
      expect(roundIndexAt(rounds, base.add(const Duration(minutes: 25))), 1);
      expect(roundIndexAt(rounds, base.add(const Duration(minutes: 35))), 2);
      expect(roundIndexAt(rounds, base.add(const Duration(hours: 5))), 2);
    });

    test('formatRoundDuration', () {
      expect(formatRoundDuration(3600), '1 цаг');
      expect(formatRoundDuration(5400), '1 цаг 30 мин');
      expect(formatRoundDuration(2700), '45 мин');
      expect(formatRoundDuration(90), '1 мин 30 сек');
      expect(formatRoundDuration(60), '1 мин');
      expect(formatRoundDuration(30), '30 сек');
      expect(formatRoundDuration(5), '5 сек');
    });

    test('formatTimeRange', () {
      final a = DateTime(2026, 11, 18, 10, 10);
      final b = DateTime(2026, 11, 18, 13, 10);
      expect(formatTimeRange(a, b), '10:10–13:10');
    });

    test('AuctionRound/rounds parse', () {
      final list = parseRounds([
        {
          'startsAt': '2026-11-18T10:00:00Z',
          'endsAt': '2026-11-18T11:00:00Z',
          'durationSec': 3600
        }
      ]);
      expect(list!.single.durationSec, 3600);
      expect(parseRounds(null), isNull);
    });
  });

  group('RequestValidators', () {
    test('title 3–120', () {
      expect(RequestValidators.title(''), isNotNull);
      expect(RequestValidators.title('ab'), isNotNull);
      expect(RequestValidators.title('abc'), isNull);
      expect(RequestValidators.title('a' * 121), isNotNull);
    });
    test('description 10–4000', () {
      expect(RequestValidators.description('богино'), isNotNull);
      expect(RequestValidators.description('x' * 10), isNull);
      expect(RequestValidators.description('x' * 4001), isNotNull);
    });
    test('startPrice хоосон эсвэл бүхэл ≥0', () {
      expect(RequestValidators.startPrice(''), isNull);
      expect(RequestValidators.startPrice('0'), isNull);
      expect(RequestValidators.startPrice('1500'), isNull);
      expect(RequestValidators.startPrice('-1'), isNotNull);
      expect(RequestValidators.startPrice('1.5'), isNotNull);
    });
  });

  test('AuctionRequest parse + canCancel', () {
    final r = AuctionRequest.fromJson({
      'id': 'r1',
      'title': 'Бараа',
      'description': 'Тайлбар текст',
      'category': 'Электроник',
      'startPrice': 5000,
      'status': 'pending',
      'adminNote': null,
      'createdAt': '2026-11-17T10:00:00.000Z',
    });
    expect(r.canCancel, true);
    expect(AuctionRequest.statusLabel('info_requested'), 'Мэдээлэл дутуу');
    expect(
        AuctionRequest.fromJson({
          'id': 'r2',
          'title': 'x',
          'description': 'y',
          'status': 'approved',
          'createdAt': '2026-11-17T10:00:00.000Z',
        }).canCancel,
        false);
  });

  test('formatBidTime: өнөөдөр HH:mm:ss, бусад өдөр MM.dd HH:mm:ss', () {
    final now = DateTime(2026, 11, 18, 15, 0, 0);
    expect(formatBidTime(DateTime(2026, 11, 18, 9, 5, 7), now), '09:05:07');
    expect(formatBidTime(DateTime(2026, 11, 17, 23, 59, 1), now),
        '11.17 23:59:01');
  });

  test('formatExactDateTime: yyyy.MM.dd HH:mm', () {
    expect(formatExactDateTime(DateTime(2026, 11, 18, 14)), '2026.11.18 14:00');
    expect(formatExactDateTime(DateTime(2026, 1, 5, 9, 7)), '2026.01.05 09:07');
  });
}
