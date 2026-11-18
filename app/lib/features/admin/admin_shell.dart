import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/auth_controller.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);
  final String path, label;
  final IconData icon;
}

class _NavSection {
  const _NavSection(this.title, this.items);
  final String title;
  final List<_NavItem> items;
}

const _sections = [
  _NavSection('Ерөнхий', [
    _NavItem('/admin', 'Хянах самбар', LucideIcons.layoutDashboard),
  ]),
  _NavSection('Худалдаа', [
    _NavItem('/admin/auctions', 'Дуудлага худалдаа', LucideIcons.gavel),
    _NavItem('/admin/requests', 'Хүсэлтүүд', LucideIcons.fileText),
    _NavItem('/admin/categories', 'Ангилал', LucideIcons.tags),
  ]),
  _NavSection('Хэрэглэгч', [
    _NavItem('/admin/users', 'Хэрэглэгчид', LucideIcons.users),
    _NavItem('/admin/feedback', 'Санал хүсэлт', LucideIcons.messageSquare),
  ]),
  _NavSection('Мөнгө', [
    _NavItem('/admin/orders', 'Захиалга', LucideIcons.package),
    _NavItem('/admin/payments', 'Төлбөр', LucideIcons.creditCard),
  ]),
];

_NavItem _current(String location) {
  final all = [for (final s in _sections) ...s.items];
  // Хамгийн урт таарах зам (/admin нь бүгдэд таардаг тул).
  all.sort((a, b) => b.path.length.compareTo(a.path.length));
  return all.firstWhere((i) => location.startsWith(i.path),
      orElse: () => all.last);
}

/// Админ бүрхүүл: зүүн цэс + дээд хэсэг. Өөрийн цагаан Theme-тэй
/// (системийн dark горимд автал өөрчлөгдөхгүй). Админ биш бол `/` руу.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.valueOrNull;
    return Theme(
      data: adminTheme(),
      child: Builder(builder: (context) {
        if (user == null && auth.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (user == null || !user.isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/');
          });
          return const Scaffold(body: SizedBox.expand());
        }
        final wide = adminIsWide(context);
        final item = _current(location);
        return Scaffold(
          backgroundColor: AdminColors.bg,
          drawer: wide
              ? null
              : Drawer(
                  width: 280,
                  child: SafeArea(
                      child: _Sidebar(location: location, closeOnTap: true)),
                ),
          body: SafeArea(
            child: Row(children: [
              if (wide)
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: AdminColors.bg,
                    border:
                        Border(right: BorderSide(color: AdminColors.border)),
                  ),
                  child: _Sidebar(location: location),
                ),
              Expanded(
                child: Column(children: [
                  _TopBar(title: item.label, name: user.name, wide: wide),
                  const Divider(),
                  Expanded(child: child),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.location, this.closeOnTap = false});
  final String location;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) {
    final cur = _current(location);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: AdminColors.accent,
                  borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(LucideIcons.gavel, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'E-Duud  ',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: 'Админ',
                      style: TextStyle(fontSize: 13, color: AdminColors.muted)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
        for (final s in _sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Text(s.title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.faint)),
          ),
          for (final i in s.items)
            _NavTile(
              item: i,
              selected: i == cur,
              onTap: () {
                if (closeOnTap) Navigator.pop(context);
                context.go(i.path);
              },
            ),
        ],
        const SizedBox(height: 20),
        _NavTile(
          item: const _NavItem('/', 'Апп руу буцах', LucideIcons.arrowLeft),
          selected: false,
          onTap: () => context.go('/'),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile(
      {required this.item, required this.selected, required this.onTap});
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? AdminColors.panel : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(children: [
              Icon(item.icon,
                  size: 16,
                  color: selected ? AdminColors.accentDark : AdminColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? AdminColors.ink : AdminColors.muted)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.title, required this.name, required this.wide});
  final String title, name;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 8),
      child: Row(children: [
        if (!wide)
          IconButton(
            icon: const Icon(LucideIcons.menu, size: 20),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        Expanded(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
        if (wide) ...[
          CircleAvatar(
            radius: 13,
            backgroundColor: AdminColors.accentSoft,
            child: Text(name.isEmpty ? 'А' : name.characters.first,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.accentDark)),
          ),
          const SizedBox(width: 8),
          Text(name,
              style: const TextStyle(fontSize: 13, color: AdminColors.muted)),
          const SizedBox(width: 14),
        ],
        AdminButton('Гарах', icon: LucideIcons.logOut, onPressed: () async {
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/');
        }),
      ]),
    );
  }
}
