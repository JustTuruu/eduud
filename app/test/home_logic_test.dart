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
}
