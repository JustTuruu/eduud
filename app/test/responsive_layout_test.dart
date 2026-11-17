// Web/утас хоёулаа нэг код: landing болон нэвтэрсэн бүрхүүл нарийн (утас)
// болон өргөн (web/desktop) дэлгэц дээр overflow-гүй зурагдаж, зөв навигац
// (доод/дээд) сонгогдож байгааг шалгана.
import 'package:eduud/core/models.dart';
import 'package:eduud/core/router.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auth/auth_controller.dart';
import 'package:eduud/features/home/home_screen.dart';
import 'package:eduud/features/landing/landing_screen.dart';
import 'package:eduud/shared/app_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _sample = [
  for (var i = 0; i < 4; i++)
    AuctionSummary(
      id: 'a$i',
      title: 'Туршилтын бараа $i',
      images: const [],
      currentPrice: 1000 + i * 50,
      bidCount: 10 + i,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(minutes: 5)),
      status: 'live',
    ),
];

class _LoggedOut extends AuthController {
  @override
  Future<UserProfile?> build() async => null;
}

class _LoggedIn extends AuthController {
  @override
  Future<UserProfile?> build() async => UserProfile(
        id: 'u1',
        phone: '99000000',
        name: 'Тест',
        role: 'user',
        balance: 7,
      );
}

Widget _app(AuthController Function() auth) => ProviderScope(
      overrides: [
        authProvider.overrideWith(auth),
        auctionListProvider.overrideWith((ref, status) async => _sample),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    );

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUpAll(() {
    // Тестэд google_fonts сүлжээнээс татахгүй — fallback фонт.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final (label, size) in [
    ('утас', const Size(390, 844)),
    ('web өргөн', const Size(1400, 1000)),
  ]) {
    testWidgets('Landing ($label): нэвтрээгүй үед / дээр overflow-гүй', (tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(_app(_LoggedOut.new));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(find.text('Бүртгүүлж эхлэх'), findsOneWidget);
      // Идэвхтэй auction картууд landing дээр шууд харагдана
      expect(find.byType(AuctionCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Нүүр ($label): нэвтэрсэн үед зөв навигац', (tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(_app(_LoggedIn.new));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LandingScreen), findsNothing);
      final wide = size.width >= 900;
      expect(find.byType(AppTopNav), wide ? findsOneWidget : findsNothing);
      expect(find.byType(AppNavBar), wide ? findsNothing : findsOneWidget);
      // Гурван таб: Нүүр, Хүсэлт, Профайл (Данс/Ялалт Профайлаас орно).
      for (final label in ['Нүүр', 'Хүсэлт', 'Профайл']) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Данс'), findsNothing);
      expect(find.text('Одоо явагдаж буй'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Нэвтрэлт шаардах зам → login?next=', (tester) async {
    await _setSize(tester, const Size(390, 844));
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(_LoggedOut.new),
      auctionListProvider.overrideWith((ref, status) async => _sample),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.dark,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    final router = container.read(routerProvider);
    router.go('/wallet');
    await tester.pump(const Duration(seconds: 1));
    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/auth/login');
    expect(uri.queryParameters['next'], '/wallet');
    expect(tester.takeException(), isNull);
  });
}
