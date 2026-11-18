import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auction/consent_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('"Оролцох" товч зөвшөөрөл тэмдэглэтэл идэвхгүй', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ConsentSheet(increment: 100),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Оролцохын өмнө'), findsOneWidget);
    expect(find.textContaining('Үнэ илгээх бүрт 1 эрх зарцуулагдана'), findsOneWidget);
    // Идэвхгүй үед товч дарагдахгүй
    await tester.tap(find.text('Оролцох'));
    await tester.pumpAndSettle();
    expect(find.text('Оролцохын өмнө'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Оролцох'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
