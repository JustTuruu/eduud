// Профайл дэлгэц нарийн/өргөн дэлгэц дээр бүх хэсэг нь exception-гүй зурагдана.
import 'package:eduud/core/models.dart';
import 'package:eduud/core/theme/app_theme.dart';
import 'package:eduud/features/auth/auth_controller.dart';
import 'package:eduud/features/orders/orders_screen.dart';
import 'package:eduud/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  for (final size in const [Size(390, 844), Size(1200, 900)]) {
    testWidgets('Профайл ${size.width.toInt()}px: tile, жагсаалт, гарах',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith(_LoggedIn.new),
          ordersProvider.overrideWith((ref) async => <OrderItem>[]),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const ProfileScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Миний эрх'), findsOneWidget);
      expect(find.text('Хожсон бараа'), findsOneWidget);
      expect(find.text('Нэр солих'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Гарах'), 300);
      expect(find.text('Гарах'), findsOneWidget);
    });
  }
}
