import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/avatars.dart';
import '../../shared/form_widgets.dart';
import '../../shared/invoice_sheet.dart' show showGlassSheet;
import '../../shared/validators.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';
import '../orders/orders_screen.dart' show ordersProvider;
import '../wallet/sub_page.dart';

/// Профайл — хүн, түүний эрх ба хожсон бараа, дараа нь тохиргооны жагсаалтууд.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final due = ref
            .watch(ordersProvider)
            .valueOrNull
            ?.where((o) => o.status == 'pending')
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'profile',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  Breakpoints.isWide(context)
                      ? 40
                      : NavMetrics.bottomInset(context)),
              children: [
                Reveal(
                  index: 0,
                  child: _Header(
                    user: user,
                    onAvatar: () => _editAvatar(context, ref, user),
                  ),
                ),
                const SizedBox(height: 28),
                Reveal(
                  index: 1,
                  // Row-ийн stretch нь ListView-д хязгааргүй өндөр авдаг тул
                  // IntrinsicHeight-аар хоёр tile-ийн өндрийг тэгшилнэ.
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _HeroTile(
                            icon: LucideIcons.gem,
                            label: 'Миний эрх',
                            value: '${user.balance}',
                            unit: 'эрх',
                            hint: 'Цэнэглэх',
                            onTap: () => context.push('/wallet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HeroTile(
                            icon: LucideIcons.trophy,
                            label: 'Хожсон бараа',
                            value: due > 0 ? '$due' : null,
                            unit: due > 0 ? 'төлөх' : null,
                            hint: due > 0 ? 'Төлбөр хүлээж байна' : 'Харах',
                            highlight: due > 0,
                            onTap: () => context.push('/orders'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Reveal(
                  index: 2,
                  child: _Group(title: 'Бүртгэл', rows: [
                    _Row(
                      icon: LucideIcons.userPen,
                      label: 'Нэр солих',
                      value: user.name,
                      onTap: () => _editName(context, ref, user.name),
                    ),
                    _Row(
                      icon: LucideIcons.palette,
                      label: 'Аватар солих',
                      onTap: () => _editAvatar(context, ref, user),
                    ),
                    _Row(
                      icon: LucideIcons.keyRound,
                      label: 'Нууц үг солих',
                      onTap: () => _changePassword(context, ref),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Reveal(
                  index: 3,
                  child: _Group(title: 'Тусламж', rows: [
                    _Row(
                      icon: LucideIcons.lifeBuoy,
                      label: 'Тусламж',
                      onTap: () => context.push('/help'),
                    ),
                    _Row(
                      icon: LucideIcons.messageSquare,
                      label: 'Санал хүсэлт',
                      onTap: () => context.push('/feedback'),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Reveal(
                  index: 4,
                  child: _Group(title: 'Нөхцөл', rows: [
                    _Row(
                      icon: LucideIcons.fileText,
                      label: 'Үйлчилгээний нөхцөл',
                      onTap: () => context.push('/content/terms'),
                    ),
                    _Row(
                      icon: LucideIcons.shieldCheck,
                      label: 'Нууцлалын бодлого',
                      onTap: () => context.push('/content/privacy'),
                    ),
                  ]),
                ),
                const SizedBox(height: 56),
                Center(
                  child: AnimatedPressable(
                    onPressed: () => _logout(context, ref),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      alignment: Alignment.center,
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(LucideIcons.logOut,
                            size: 18, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text('Гарах',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.danger)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text('E-Duud 0.1.0',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Нэр ----------

  Future<void> _editName(
      BuildContext context, WidgetRef ref, String current) async {
    // Controller-ийг dialog өөрөө эзэмшинэ — эндээс дамжуулж өгөөд гаднаас
    // dispose хийвэл хаагдах animation дээр "used after dispose" алдаа гарна.
    final saved = await showAppDialog<bool>(
      context,
      builder: (ctx) => _EditNameDialog(initialName: current, ref: ref),
    );

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нэр солигдлоо.')));
    }
  }

  // ---------- Аватар ----------

  Future<void> _editAvatar(
      BuildContext context, WidgetRef ref, UserProfile user) async {
    final picked = await showGlassSheet<String>(
      context,
      builder: (ctx) => AvatarPicker(name: user.name, current: user.avatarUrl),
    );
    if (picked == null) return;

    try {
      await ref.read(dioProvider).patch('/me', data: {'avatarUrl': picked});
      await ref.read(authProvider.notifier).refreshProfile();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Аватар солигдлоо.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  // ---------- Нууц үг ----------

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final changed = await showAppDialog<bool>(
      context,
      builder: (ctx) => _ChangePasswordDialog(ref: ref),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Нууц үг солигдлоо.')));
    }
  }

  // ---------- Гарах ----------

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Гарах уу?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            const Text('Дахин орохдоо нэвтэрнэ.',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Гарах',
              icon: LucideIcons.logOut,
              gradient: AppColors.dangerGradient,
              // Улаан gradient бараан тул цагаан текст тод харагдана.
              foreground: Colors.white,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Болих',
                  style: TextStyle(color: AppColors.inkSoft)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/auth/login');
    }
  }
}

// ---------------------------------------------------------------------------

/// Толгой — аватар, нэр, утас зүүн талдаа; админ бол жижиг тэмдэг.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onAvatar});

  final UserProfile user;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Semantics(
        button: true,
        label: 'Аватар солих',
        child: AnimatedPressable(
          onPressed: onAvatar,
          child: Stack(clipBehavior: Clip.none, children: [
            AppAvatar(name: user.name, avatarUrl: user.avatarUrl, size: 76),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceHi,
                  border: Border.all(color: AppColors.bg, width: 2.5),
                ),
                child: const Icon(LucideIcons.pencil,
                    size: 12, color: AppColors.ink),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(width: 18),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(user.phone,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.inkSoft,
                    fontFeatures: [FontFeature.tabularFigures()])),
            if (user.isAdmin) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHi.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(LucideIcons.badgeCheck,
                      size: 13, color: AppColors.inkSoft),
                  SizedBox(width: 6),
                  Text('Админ',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkSoft)),
                ]),
              ),
            ],
          ],
        ),
      ),
    ]);
  }
}

/// "Миний эрх" / "Хожсон бараа" — профайлын хоёр гол орц.
class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.value,
    this.unit,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? unit;
  final String hint;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label ${value ?? ''} ${unit ?? ''}',
      child: AnimatedPressable(
        onPressed: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 144),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlight
                  ? AppColors.coral.withValues(alpha: 0.5)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: AppColors.coralLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft)),
                ),
              ]),
              const SizedBox(height: 14),
              if (value != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value!,
                            style:
                                AppTheme.price(size: 40).copyWith(height: 1)),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 6),
                      Text(unit!,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkSoft)),
                    ],
                  ],
                )
              else
                const Text('Бүгд',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: AppColors.ink)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: Text(hint,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.coralLight)),
                ),
                const Icon(LucideIcons.chevronRight,
                    size: 16, color: AppColors.coralLight),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Тохиргооны бүлэг — гарчиг + 1px хуваагчтай мөрүүд (тус тусдаа карт биш).
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlainLabel(title),
        const SizedBox(height: 4),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++)
              Container(
                decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.border)),
                ),
                child: rows[i],
              ),
          ]),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onPressed: onTap,
      scale: 0.99,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        color: Colors.transparent,
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.inkSoft),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ),
          if (value != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.inkSoft)),
              ),
            ),
          const Icon(LucideIcons.chevronRight,
              size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName, required this.ref});

  final String initialName;
  final WidgetRef ref;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  bool _loading = false;
  String? _error;
  int _shake = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = Validators.name(_controller.text);
    setState(() => _error = error);
    if (error != null) {
      setState(() => _shake++);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.ref
          .read(dioProvider)
          .patch('/me', data: {'name': _controller.text.trim()});
      await widget.ref.read(authProvider.notifier).refreshProfile();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = apiErrorMessage(e);
          _shake++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Нэр солих',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 20),
          AppField(
            label: 'Нэр',
            controller: _controller,
            hint: 'Шинэ нэр',
            icon: LucideIcons.user,
            error: _error,
            autofocus: true,
            enabled: !_loading,
            shakeToken: _shake,
            maxLength: Validators.nameMax,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Хадгалах',
            loading: _loading,
            onPressed: _loading ? null : _save,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child:
                const Text('Болих', style: TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  int _shake = 0;
  String? _formError;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final currentError =
        _current.text.isEmpty ? 'Одоогийн нууц үгээ бичнэ үү' : null;
    final nextError = Validators.password(_next.text);
    final confirmError = Validators.confirmPassword(_confirm.text, _next.text);

    setState(() {
      _currentError = currentError;
      _nextError = nextError;
      _confirmError = confirmError;
      _formError = null;
    });

    if (currentError != null || nextError != null || confirmError != null) {
      setState(() => _shake++);
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.ref.read(dioProvider).post('/me/password', data: {
        'currentPassword': _current.text,
        'newPassword': _next.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _formError = apiErrorMessage(e);
          _shake++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Нууц үг солих',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 20),
          ErrorBanner(message: _formError, shakeToken: _shake),
          PasswordField(
            label: 'Одоогийн нууц үг',
            controller: _current,
            hint: 'Одоогийн нууц үг',
            error: _currentError,
            enabled: !_loading,
            shakeToken: _shake,
            textInputAction: TextInputAction.next,
            onChanged: (_) {
              if (_currentError != null) setState(() => _currentError = null);
            },
          ),
          const SizedBox(height: 14),
          PasswordField(
            label: 'Шинэ нууц үг',
            controller: _next,
            hint: 'Хамгийн багадаа 8 тэмдэгт',
            error: _nextError,
            enabled: !_loading,
            shakeToken: _shake,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {
              if (_nextError != null) {
                _nextError = Validators.password(_next.text);
              }
              if (_confirmError != null) {
                _confirmError =
                    Validators.confirmPassword(_confirm.text, _next.text);
              }
            }),
          ),
          PasswordStrengthMeter(password: _next.text),
          const SizedBox(height: 14),
          PasswordField(
            label: 'Шинэ нууц үгээ давтах',
            controller: _confirm,
            hint: 'Дахин бичнэ үү',
            error: _confirmError,
            enabled: !_loading,
            shakeToken: _shake,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_confirmError != null) {
                setState(() => _confirmError =
                    Validators.confirmPassword(_confirm.text, _next.text));
              }
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Хадгалах',
            loading: _loading,
            onPressed: _loading ? null : _save,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child:
                const Text('Болих', style: TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}
