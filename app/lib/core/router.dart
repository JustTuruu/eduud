import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../features/auction/auction_detail_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_flow_screen.dart';
import '../features/content/content_screen.dart';
import '../features/feedback/feedback_screen.dart';
import '../features/help/help_screen.dart';
import '../features/home/home_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../shared/app_nav_bar.dart';
import 'theme/app_theme.dart';

/// Дэлгэц баруунаас гулсаж орж ирнэ — урагш ахих чиглэлийг илэрхийлнэ.
CustomTransitionPage<T> _slidePage<T>(GoRouterState state, Widget child) {
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
      return s.valueOrNull != null ? _AuthStatus.loggedIn : _AuthStatus.loggedOut;
    }),
  );

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onAuth = state.matchedLocation.startsWith('/auth');
      if (status == _AuthStatus.unknown) return null;
      if (status == _AuthStatus.loggedOut && !onAuth) return '/auth/login';
      if (status == _AuthStatus.loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/auth/login',
        pageBuilder: (_, state) => _slidePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/auth/register',
        pageBuilder: (_, state) =>
            _slidePage(state, const OtpFlowScreen(purpose: 'register')),
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
      GoRoute(
        path: '/feedback',
        pageBuilder: (_, state) => _slidePage(state, const FeedbackScreen()),
      ),
      GoRoute(
        path: '/help',
        pageBuilder: (_, state) => _slidePage(state, const HelpScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

const _destinations = [
  NavDestination(icon: LucideIcons.gavel, label: 'Нүүр'),
  NavDestination(icon: LucideIcons.wallet, label: 'Данс'),
  NavDestination(icon: LucideIcons.trophy, label: 'Ялалт'),
  NavDestination(icon: LucideIcons.user, label: 'Профайл'),
];

class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedShellBody(index: shell.currentIndex, child: shell),
      bottomNavigationBar: AppNavBar(
        destinations: _destinations,
        currentIndex: shell.currentIndex,
        onSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
