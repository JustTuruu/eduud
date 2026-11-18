// Админ хэсэг: самбар хоёр өргөнд алдаагүй зурагдана, админ биш хүн redirect
// болно, ангиллын мөрүүд харагдана.
import 'package:eduud/core/models.dart';
import 'package:eduud/features/admin/admin_api.dart';
import 'package:eduud/features/admin/admin_categories.dart';
import 'package:eduud/features/admin/admin_dashboard.dart';
import 'package:eduud/features/admin/admin_shell.dart';
import 'package:eduud/features/admin/admin_theme.dart';
import 'package:eduud/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Auth extends AuthController {
  _Auth(this.role);
  final String role;
  @override
  Future<UserProfile?> build() async => UserProfile(
      id: 'u1', phone: '99000000', name: 'Бат', role: role, balance: 0);
}

final _statsJson = <String, dynamic>{
  'users': {'total': 120, 'newToday': 4, 'new7d': 21, 'banned': 1},
  'auctions': {
    'live': 3,
    'scheduled': 2,
    'draft': 1,
    'endedToday': 1,
    'total': 20
  },
  'bids': {
    'today': 412,
    'last24h': 530,
    'total': 9000,
    'perHour': [
      for (var h = 0; h < 24; h++) {'hour': h, 'count': h * 3}
    ],
  },
  'revenue': {
    'todayMnt': 150000,
    'periodMnt': 2400000,
    'perDay': [
      for (var d = 1; d <= 14; d++)
        {
          'date': '2026-11-${d.toString().padLeft(2, '0')}',
          'topupMnt': d * 10000,
          'orderMnt': d * 5000,
        }
    ],
  },
  'tokens': {
    'soldToday': 100,
    'soldPeriod': 900,
    'spentToday': 412,
    'inCirculation': 5000
  },
  'orders': {'pendingPayment': 2, 'paid': 5, 'toDeliver': 3, 'expired': 1},
  'requests': {'pending': 2, 'reviewing': 1, 'infoRequested': 1},
  'feedback': {'open': 3},
  'pipeline': {
    'mode': 'kafka',
    'accepted': 900,
    'rejected': 20,
    'duplicate': 5,
    'avgEndToEndMs': 42.5,
    'p95EndToEndMs': 120.0,
  },
  'topAuctions': [
    {
      'id': 'a1',
      'title': 'iPhone 15',
      'status': 'live',
      'bidCount': 300,
      'currentPrice': 45000,
      'bidsLast24h': 120,
    },
  ],
};

void main() {
  for (final size in const [Size(1280, 900), Size(390, 844)]) {
    testWidgets('Самбар ${size.width.toInt()}px: KPI карт, overflow-гүй',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          adminStatsProvider
              .overrideWith((ref) async => AdminStats.fromJson(_statsJson)),
        ],
        child: MaterialApp(
          theme: adminTheme(),
          home: const Scaffold(body: AdminDashboardScreen()),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Идэвхтэй дуудлага'), findsOneWidget);
      expect(find.text('Өнөөдрийн санал'), findsOneWidget);
      expect(find.text('Өнөөдрийн орлого'), findsOneWidget);
      expect(find.text('Шинэ хэрэглэгч'), findsOneWidget);
      expect(find.text('Хүргэх захиалга'), findsOneWidget);
      expect(find.text('Хүлээгдэж буй хүсэлт'), findsOneWidget);
      expect(find.text('412'), findsWidgets);
      expect(find.text('150,000₮'), findsOneWidget);
      // Доод хэсгийг гүйлгэж Kafka самбар, топ хүснэгтийг шалгана
      await tester.scrollUntilVisible(find.text('Kafka pipeline'), 300);
      await tester.scrollUntilVisible(find.text('iPhone 15'), 300);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Хоосон/дутуу stats задрахад унахгүй', (tester) async {
    final s = AdminStats.fromJson({});
    expect(s.bidsToday, 0);
    expect(s.pipeline.avgMs, isNull);
    expect(s.topAuctions, isEmpty);
  });

  GoRouter router() => GoRouter(initialLocation: '/admin', routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('НҮҮР')),
        ShellRoute(
          builder: (_, s, child) =>
              AdminShell(location: s.uri.path, child: child),
          routes: [
            GoRoute(
                path: '/admin',
                builder: (_, __) => const Text('САМБАРЫН АГУУЛГА')),
          ],
        ),
      ]);

  testWidgets('Админ биш хэрэглэгч / руу шилжинэ', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => _Auth('user'))],
      child: MaterialApp.router(routerConfig: router()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('НҮҮР'), findsOneWidget);
    expect(find.text('САМБАРЫН АГУУЛГА'), findsNothing);
  });

  testWidgets('Админд бүрхүүл ба цэс харагдана', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => _Auth('admin'))],
      child: MaterialApp.router(routerConfig: router()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('САМБАРЫН АГУУЛГА'), findsOneWidget);
    expect(find.text('Ангилал'), findsOneWidget);
    expect(find.text('Бат'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ангиллын мөрүүд харагдана', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        adminCategoriesProvider.overrideWith((ref) async => const [
              AdminCategory(
                  id: 'c1',
                  name: 'Электроник',
                  sortOrder: 1,
                  active: true,
                  auctionCount: 4),
              AdminCategory(
                  id: 'c2',
                  name: 'Хувцас',
                  sortOrder: 2,
                  active: false,
                  auctionCount: 0),
            ]),
      ],
      child: MaterialApp(
        theme: adminTheme(),
        home: const Scaffold(body: AdminCategoriesScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Электроник'), findsOneWidget);
    expect(find.text('Хувцас'), findsOneWidget);
    expect(find.text('Ангилал нэмэх'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
