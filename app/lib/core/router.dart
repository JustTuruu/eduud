import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPage;

import '../features/auction/auction_detail_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_flow_screen.dart';
import '../features/content/content_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/help/help_screen.dart';
import '../features/home/auction_list_screen.dart';
import '../features/home/home_screen.dart';
import '../features/landing/landing_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/requests/requests_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../shared/app_nav_bar.dart';
import '../shared/responsive.dart';
import '../shared/widgets.dart';
import 'theme/app_theme.dart';

/// Дэлгэц баруунаас гулсаж орж ирнэ — урагш ахих чиглэлийг илэрхийлнэ.
/// iOS/macOS дээр жинхэнэ Cupertino шилжилт (зүүн ирмэгээс чирж буцах),
/// бусад дээр зөөлөн slide+fade.
Page<T> _slidePage<T>(GoRouterState state, Widget child) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    return CupertinoPage<T>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.exitFast,
    transitionsBuilder: (context, anim, secondary, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: AppMotion.fluid,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum _AuthStatus { unknown, loggedIn, loggedOut }

/// Нэвтрээгүй хэрэглэгч орж болохгүй замууд. Бусад нь (landing, auction
/// дэлгэрэнгүй, контент, тусламж) нээлттэй — web дээр холбоос хуваалцахад,
/// утас дээр апп татсан хүн бүртгүүлэхээсээ өмнө үзэж танилцахад.
bool _requiresAuth(String location) {
  return location.startsWith('/wallet') ||
      location.startsWith('/orders') ||
      location.startsWith('/profile') ||
      location.startsWith('/requests') ||
      location.startsWith('/feedback');
}

/// Нэвтрэх дэлгэц рүү `next` параметртэй илгээнэ — нэвтэрсний дараа тэр
/// газраа буцааж аваачна (жиш. оролцох гэж байсан auction).
String loginLocation({String? next}) {
  if (next == null || next == '/' || !next.startsWith('/')) {
    return '/auth/login';
  }
  return Uri(path: '/auth/login', queryParameters: {'next': next}).toString();
}

final routerProvider = Provider<GoRouter>((ref) {
  // Зөвхөн "нэвтэрсэн эсэх" өөрчлөгдөхөд router дахин үүснэ.
  //
  // Бүтэн auth төлөвийг ажиглавал нэр/аватар шинэчлэх бүрд шинэ GoRouter
  // үүсэж, StatefulShellRoute-ийн төлөв тэглэгдэн хэрэглэгчийг Нүүр таб руу
  // буцаана. `select` нь утга үнэхээр өөрчлөгдсөн үед л мэдэгдэнэ.
  final status = ref.watch(
    authProvider.select((s) {
      // Профайл сэргээх үед төлөв түр AsyncLoading болох ч өмнөх утга хэвээр
      // үлддэг. Үүнийг "тодорхойгүй" гэж үзвэл router дахин үүсээд навигаци
      // тэглэгдэнэ — тиймээс утга огт байхгүй үед л unknown гэнэ.
      if (s.isLoading && !s.hasValue) return _AuthStatus.unknown;
      return s.valueOrNull != null
          ? _AuthStatus.loggedIn
          : _AuthStatus.loggedOut;
    }),
  );
  final loggedIn = status == _AuthStatus.loggedIn;

  return GoRouter(
    // Web дээр хуудсыг дахин ачаалахад (auth unknown → loggedIn болж router
    // дахин үүсэх үед) браузерын одоогийн хаягаас эхэлнэ — үгүй бол үргэлж
    // Нүүр рүү буцаж /requests, /profile дээрх reload алдагдана.
    initialLocation: kIsWeb
        ? (Uri.base.path.isEmpty ? '/' : Uri.base.path) +
            (Uri.base.hasQuery ? '?${Uri.base.query}' : '')
        : '/',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final onAuth = loc.startsWith('/auth');
      if (status == _AuthStatus.unknown) return null;
      if (loggedIn && onAuth) {
        final next = state.uri.queryParameters['next'];
        return (next != null && next.startsWith('/')) ? next : '/';
      }
      if (!loggedIn && _requiresAuth(loc)) {
        return loginLocation(next: state.uri.toString());
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        pageBuilder: (_, state) => _slidePage(
          state,
          LoginScreen(next: state.uri.queryParameters['next']),
        ),
      ),
      GoRoute(
        path: '/auth/register',
        pageBuilder: (_, state) => _slidePage(
          state,
          OtpFlowScreen(
            purpose: 'register',
            next: state.uri.queryParameters['next'],
          ),
        ),
      ),
      GoRoute(
        path: '/auth/forgot',
        pageBuilder: (_, state) =>
            _slidePage(state, const OtpFlowScreen(purpose: 'reset')),
      ),
      GoRoute(
        path: '/auctions/:id',
        pageBuilder: (_, state) => _slidePage(
          state,
          AuctionDetailScreen(auctionId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/content/:key',
        pageBuilder: (_, state) => _slidePage(
          state,
          ContentScreen(contentKey: state.pathParameters['key']!),
        ),
      ),
      // Данс ба Ялалт — Профайлаас орох, shell-ээс гадуурх энгийн дэлгэц
      // (нэвтрэлт шаардана — _requiresAuth).
      GoRoute(
        path: '/wallet',
        pageBuilder: (_, state) => _slidePage(state, const WalletScreen()),
      ),
      GoRoute(
        path: '/orders',
        pageBuilder: (_, state) => _slidePage(state, const OrdersScreen()),
      ),
      // Нүүрний "Бүгд" — удахгүй эхлэх / дууссан дуудлагын бүтэн жагсаалт.
      GoRoute(
        path: '/lists/:status',
        pageBuilder: (_, state) => _slidePage(
          state,
          AuctionListScreen(status: state.pathParameters['status']!),
        ),
      ),
      GoRoute(
        path: '/feedback',
        pageBuilder: (_, state) => _slidePage(state, const FeedbackScreen()),
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (_, state) => _slidePage(state, const HelpScreen()),
      ),
      if (loggedIn)
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/requests',
                  builder: (_, __) => const RequestsScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/profile', builder: (_, __) => const ProfileScreen()),
            ]),
          ],
        )
      else ...[
        // Нэвтрээгүй үед `/` нь landing page. Төлөв тодорхойгүй (token
        // шалгаж байх) агшинд хоосон дэлгэц — landing/нүүр хооронд
        // анивчихгүй.
        GoRoute(
          path: '/',
          builder: (_, __) => status == _AuthStatus.unknown
              ? const _Splash()
              : const LandingScreen(),
        ),
        // Нэвтрэлт шаардах замууд: redirect нэвтрэх дэлгэц рүү аваачна.
        // Route байхгүй бол go_router "олдсонгүй" хуудас харуулах тул
        // хоосон placeholder бүртгэнэ.
        for (final p in const ['/requests', '/profile'])
          GoRoute(path: p, builder: (_, __) => const _Splash()),
      ],
    ],
  );
});

const _destinations = [
  NavDestination(icon: CupertinoIcons.house_fill, label: 'Нүүр'),
  NavDestination(icon: CupertinoIcons.doc_text_fill, label: 'Хүсэлт'),
  NavDestination(
      icon: CupertinoIcons.person_crop_circle_fill, label: 'Профайл'),
];

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AppBackground(child: SizedBox.expand()));
}

/// Нэвтэрсэн хэрэглэгчийн бүрхүүл. Утас: доод нав. Өргөн дэлгэц (web):
/// дээд нав + агуулга — ижил 3 таб, ижил төлөв.
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell> {
  /// Доод нав хураагдсан эсэх (агуулгыг доош гүйлгэхэд).
  bool _collapsed = false;

  /// Нэг чиглэлд гүйлгэсэн хуримтлагдсан зай — босго (12px) давахад нав хувирна.
  double _acc = 0;

  static const _threshold = 12.0;

  void _setCollapsed(bool v) {
    if (_collapsed == v) return;
    setState(() => _collapsed = v);
  }

  @override
  void didUpdateWidget(covariant _AppShell old) {
    super.didUpdateWidget(old);
    // Таб солигдоход нав дахин бүтэн хэлбэртэй болно.
    if (old.shell.currentIndex != widget.shell.currentIndex) {
      _acc = 0;
      _collapsed = false;
    }
  }

  /// Зөвхөн босоо гүйлгэлтийг сонсоно (хэвтээ carousel-ыг үл тоомсорлоно).
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is! ScrollUpdateNotification) return false;
    final m = n.metrics;
    // Хүрээнээс гарсан (iOS bounce) гүйлгэлтийг үл тоомсорлоно.
    if (m.outOfRange) return false;
    final d = n.scrollDelta ?? 0;
    if (d == 0) return false;
    if ((d > 0) != (_acc > 0)) _acc = 0;
    _acc += d;
    if (_acc > _threshold) {
      _setCollapsed(true);
    } else if (_acc < -_threshold) {
      // Зөвхөн дээш гүйлгэх үед л дахин өргөжинө (байрлалаар автоматаар биш).
      _setCollapsed(false);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final wide = Breakpoints.isWide(context);
    void select(int i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex);

    if (wide) {
      final user = ref.watch(authProvider).valueOrNull;
      // Нав агуулгын ДЭЭР хөвж,
      // агуулга нь навын өндрөөр дээд padding авна (SafeArea-аар).
      final mq = MediaQuery.of(context);
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          const Positioned.fill(child: AppBackground(child: SizedBox.shrink())),
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding
                    .copyWith(top: mq.padding.top + NavMetrics.topHeight),
              ),
              child: AnimatedShellBody(index: shell.currentIndex, child: shell),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppTopNav(
              destinations: _destinations,
              currentIndex: shell.currentIndex,
              onSelected: select,
              trailing: user == null
                  ? null
                  : TokenBalanceChip(
                      balance: user.balance,
                      onTap: () => context.push('/wallet'),
                    ),
            ),
          ),
        ]),
      );
    }

    return Scaffold(
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: AnimatedShellBody(index: shell.currentIndex, child: shell),
      ),
      bottomNavigationBar: AppNavBar(
        destinations: _destinations,
        currentIndex: shell.currentIndex,
        onSelected: select,
        collapsed: _collapsed,
        onExpand: () => _setCollapsed(false),
      ),
    );
  }
}
