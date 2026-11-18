// Дээд toast: нэг зэрэг ганц, ижил мессеж давхцахгүй, автоматаар хаагдана.
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/shared/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    return ctx;
  }

  testWidgets(
      'харагдана, ижил мессеж давхцахгүй, шинэ нь солино, 3с-д хаагдана',
      (tester) async {
    final ctx = await pumpHost(tester);

    showTopToast(ctx, 'Нэг');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Нэг'), findsOneWidget);

    showTopToast(ctx, 'Нэг');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Нэг'), findsOneWidget);

    showTopToast(ctx, 'Хоёр', kind: TopToastKind.error);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Нэг'), findsNothing);
    expect(find.text('Хоёр'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Хоёр'), findsNothing);
  });
}
