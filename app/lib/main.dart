import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/url_strategy/url_strategy.dart';

void main() {
  // Web дээр /auctions/abc гэх мэт цэвэр URL (#-гүй) — landing page-ийн
  // холбоос хуваалцахад, SEO-д чухал. Mobile дээр no-op.
  configureUrlStrategy();
  runApp(const ProviderScope(child: EduudApp()));
}

class EduudApp extends ConsumerWidget {
  const EduudApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'E-Duud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
