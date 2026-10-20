import 'package:flutter_test/flutter_test.dart';

import 'package:eduud/core/models.dart';

void main() {
  test('AuctionSummary JSON parse', () {
    final a = AuctionSummary.fromJson({
      'id': 'a1',
      'title': 'Туршилт',
      'images': ['https://x/y.jpg'],
      'currentPrice': 4780,
      'bidCount': 126,
      'startsAt': '2026-01-01T00:00:00.000Z',
      'endsAt': '2026-01-01T01:00:00.000Z',
      'status': 'live',
      'lastBidder': {'id': 'u1', 'name': 'Түвшин', 'avatarUrl': null},
    });
    expect(a.title, 'Туршилт');
    expect(a.currentPrice, 4780);
    expect(a.lastBidder?.name, 'Түвшин');
  });

  test('UserProfile isAdmin', () {
    final u = UserProfile.fromJson({
      'id': 'u1',
      'phone': '99000000',
      'name': 'Админ',
      'role': 'admin',
      'balance': 5,
    });
    expect(u.isAdmin, true);
    expect(u.balance, 5);
  });
}
