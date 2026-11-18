// Хүсэлтийн tab: тойм (алхмууд), маягтын шошго/алдаа, өргөн дэлгэц.
import 'package:eduud/core/models.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/requests/request_validators.dart';
import 'package:eduud/features/requests/requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(List<AuctionRequest> list) => ProviderScope(
      overrides: [myRequestsProvider.overrideWith((ref) async => list)],
      child: MaterialApp(theme: AppTheme.light, home: const RequestsScreen()),
    );

void main() {
  for (final size in const [Size(390, 844), Size(1200, 900)]) {
    testWidgets('Хүсэлт ${size.width.toInt()}px: хоосон үед алхмууд',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app([]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.text('Шинэ хүсэлт илгээх'), findsOneWidget);
      expect(find.text('Хэрхэн явагддаг вэ'), findsOneWidget);
      expect(find.text('Барааныхаа мэдээллийг илгээнэ'), findsOneWidget);
    });

    testWidgets('Хүсэлт ${size.width.toInt()}px: маягт шошго, алдаа',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app([]));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Шинэ хүсэлт илгээх'));
      await tester.pumpAndSettle();
      expect(find.text('Шинэ хүсэлт'), findsOneWidget);
      expect(find.text('Болих'), findsOneWidget);
      expect(find.textContaining('Барааны нэр', findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('Ангилал', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Илгээх'));
      await tester.pumpAndSettle();
      expect(find.text(RequestValidators.title('')!), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.text('Хамаагүй'), findsOneWidget);
      expect(find.text(RequestValidators.description('')!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Хүсэлтүүд байвал жагсаалт, статус харагдана', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app([
      AuctionRequest(
        id: 'r1',
        title: 'iPhone 15',
        description: 'сайн',
        status: 'draft',
        category: 'Электроник',
        startPrice: 1500000,
        createdAt: DateTime(2026, 11, 1),
      ),
    ]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Миний хүсэлтүүд'), findsOneWidget);
    expect(find.text('Ноорог'), findsOneWidget);
    expect(find.text('Цуцлах'), findsOneWidget);
    expect(find.text('Хэрхэн явагддаг вэ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
