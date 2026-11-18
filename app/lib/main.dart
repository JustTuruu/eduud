import 'dart:ui' show PlatformDispatcher;

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

class EduudApp extends ConsumerStatefulWidget {
  const EduudApp({super.key});

  @override
  ConsumerState<EduudApp> createState() => _EduudAppState();
}

/// Системийн light/dark солигдоход [AppColors]-ийн багцыг сольж, бүх
/// widget-ийг дахин зурна. AppColors нь static тул Theme-д хамааралгүй
/// widget-үүд өөрсдөө мэдэхгүй — тиймээс element мод дагуу markNeedsBuild
/// хийнэ (Navigator/router-ийн төлөв устахгүй).
class _EduudAppState extends ConsumerState<EduudApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    AppColors.apply(PlatformDispatcher.instance.platformBrightness);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    AppColors.apply(PlatformDispatcher.instance.platformBrightness);
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'E-Duud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
