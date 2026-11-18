// Зургийг дарахад "Peek" карт нээгдэх, backdrop дарахад хаагдахыг шалгана.
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/image_peek.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showImagePeek: нээгдэж, backdrop-оор хаагдана', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showImagePeek(context,
                  images: const ['http://x/a.png', 'http://x/b.png']),
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
            onPressed: () =>
                showImagePeek(context, images: const ['http://x/a.png']),
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
}
