// Зургийг дарахад "Peek" карт нээгдэх, backdrop дарахад хаагдахыг шалгана.
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/image_peek.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
ImageProvider _mem(String _) => MemoryImage(_png);

void main() {
  testWidgets('showImagePeek: нээгдэж, backdrop-оор хаагдана', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showImagePeek(context,
                  images: const ['http://x/a.png', 'http://x/b.png'],
                  providerFor: _mem),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);
    // Арын хуудас үлдсэн хэвээр
    expect(find.text('open'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);

    // × товчоор хаах
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('доош чирж хаах', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showImagePeek(context,
                images: const ['http://x/a.png'], providerFor: _mem),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 300),
        warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  Widget host(List<String> imgs, int initial) => MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showImagePeek(context,
                  images: imgs, initial: initial, providerFor: _mem),
              child: const Text('open'),
            ),
          ),
        ),
      );

  testWidgets('3 зурагтай: 3 цэг, swipe хийхэд идэвхтэй хуудас солигдоно',
      (tester) async {
    await tester.pumpWidget(host(const ['a', 'b', 'c'], 1));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('peek-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('peek-dot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('peek-dot-2')), findsOneWidget);
    // Дарсан индексээс эхэлнэ
    expect(find.text('2 / 3'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('peek-dot-1'))).width, 24);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('peek-dot-2'))).width, 24);
    expect(tester.getSize(find.byKey(const ValueKey('peek-dot-1'))).width, 12);
  });

  testWidgets('1 зурагтай үед цэг харагдахгүй', (tester) async {
    await tester.pumpWidget(host(const ['a'], 0));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('peek-dot-0')), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
  });
}
