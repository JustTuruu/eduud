import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';

/// Нэвтрэх / бүртгүүлэх дэлгэцүүдийн нийтлэг бүрхүүл: iOS маягийн дээд мөр
/// (буцах сум), доор нь том гарчигтай нэг багана. Өргөн дэлгэц дээр голд нь.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.onBack,
    this.backEnabled = true,
    this.maxWidth = 440,
  });

  final Widget child;

  /// Өгөөгүй бол өмнөх дэлгэц рүү (түүх байхгүй бол `/`).
  final VoidCallback? onBack;
  final bool backEnabled;
  final double maxWidth;

  void _defaultBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final enabled = backEnabled;
    return AuthBackground(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth + 40),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Буцах',
                      child: InkResponse(
                        onTap: enabled
                            ? (onBack ?? () => _defaultBack(context))
                            : null,
                        radius: 24,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(CupertinoIcons.chevron_back,
                                size: 22,
                                color:
                                    enabled ? AppColors.accent : AppColors.muted),
                            Text('Буцах',
                                style: TextStyle(
                                    fontSize: 17,
                                    color: enabled
                                        ? AppColors.accent
                                        : AppColors.muted)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(20, wide ? 24 : 8, 20, 32),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Дэлгэцийн том гарчиг (34/700) + нэг мөр тайлбар.
class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(fontSize: 17, height: 1.4, color: AppColors.muted),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
