import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/app_nav_bar.dart' show Wordmark;
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';

/// Нэвтрэх / бүртгүүлэх дэлгэцүүдийн нийтлэг бүрхүүл: ambient талбар,
/// дээд талд буцах + wordmark, голд нь тайван нэг багана. Өргөн дэлгэц дээр
/// маягт нэг чавган самбар дээр сууна.
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
    final body = wide
        ? Container(
            padding: const EdgeInsets.fromLTRB(36, 36, 36, 32),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(AppRadius.art),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: child,
          )
        : child;

    return AuthBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            // Гарын өндрийг Scaffold өөрөө нөхдөг тул viewInsets давхар нэмэхгүй.
            padding: EdgeInsets.fromLTRB(wide ? 32 : 20, 8, wide ? 32 : 20, 32),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Column(
                children: [
                  Row(children: [
                    _BackButton(
                      onPressed: backEnabled
                          ? (onBack ?? () => _defaultBack(context))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Wordmark(size: 19, onTap: () => context.go('/')),
                  ]),
                  SizedBox(height: wide ? 40 : 28),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: reducedMotion(context) ? 1 : 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: AppMotion.fluid,
                    builder: (context, t, c) => Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                          offset: Offset(0, 20 * (1 - t)), child: c),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Буцах',
      child: AnimatedPressable(
        onPressed: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: 0.7),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(LucideIcons.arrowLeft,
              size: 20,
              color: onPressed == null ? AppColors.muted : AppColors.ink),
        ),
      ),
    );
  }
}

/// Дэлгэцийн гарчиг + тайлбар — зүүн тийш, цөцгий.
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
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: 32,
                height: 1.1,
                color: AppColors.ink,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
