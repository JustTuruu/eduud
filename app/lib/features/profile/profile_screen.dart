import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/avatars.dart';
import '../../shared/form_widgets.dart';
import '../../shared/validators.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: PageFrame(
            maxWidth: 720,
            child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
            children: [
              _Header(user: user),
              const SizedBox(height: 26),

              const SectionLabel('Бүртгэл'),
              const SizedBox(height: 12),
              _MenuTile(
                icon: LucideIcons.userPen,
                label: 'Нэр солих',
                value: user.name,
                onTap: () => _editName(context, ref, user.name),
              ),
              _MenuTile(
                icon: LucideIcons.palette,
                label: 'Аватар солих',
                onTap: () => _editAvatar(context, ref, user),
              ),
              _MenuTile(
                icon: LucideIcons.keyRound,
                label: 'Нууц үг солих',
                onTap: () => _changePassword(context, ref),
              ),

              const SizedBox(height: 22),
              const SectionLabel('Дэмжлэг'),
              const SizedBox(height: 12),
              _MenuTile(
                icon: LucideIcons.lifeBuoy,
                label: 'Тусламж',
                onTap: () => context.push('/help'),
              ),
              _MenuTile(
                icon: LucideIcons.messageSquare,
                label: 'Санал хүсэлт',
                onTap: () => context.push('/feedback'),
              ),

              const SizedBox(height: 22),
              const SectionLabel('Мэдээлэл'),
              const SizedBox(height: 12),
              _MenuTile(
                icon: LucideIcons.fileText,
                label: 'Үйлчилгээний нөхцөл',
                onTap: () => context.push('/content/terms'),
              ),
              _MenuTile(
                icon: LucideIcons.shieldCheck,
                label: 'Нууцлалын бодлого',
                onTap: () => context.push('/content/privacy'),
              ),

              const SizedBox(height: 30),
              _MenuTile(
                icon: LucideIcons.logOut,
                label: 'Гарах',
                color: AppColors.danger,
                onTap: () => _logout(context, ref),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('E-Duud 0.1.0',
                    style: text.bodySmall?.copyWith(fontSize: 11.5)),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  // ---------- Нэр ----------

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
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
    final picked = await showAppSheet<String>(
      context,
      builder: (ctx) => _AvatarSheet(user: user),
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
            Text('Гарах уу?', style: Theme.of(ctx).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text('Та дахин нэвтрэх шаардлагатай болно.',
                style: Theme.of(ctx).textTheme.bodySmall),
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
              child: const Text('Болих', style: TextStyle(color: AppColors.muted)),
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

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            OpalRing(
              size: 110,
              strokeWidth: 3,
              child: AppAvatar(
                name: user.name,
                avatarUrl: user.avatarUrl,
                size: 92,
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceHi,
                  border: Border.all(color: AppColors.bg, width: 3),
                ),
                child: const Icon(LucideIcons.palette,
                    size: 13, color: AppColors.sapphireSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(user.name, style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 4),
        Text(user.phone, style: Theme.of(context).textTheme.bodySmall),
        if (user.isAdmin) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.badgeCheck, size: 12, color: AppColors.gold),
              SizedBox(width: 6),
              Text('Админ',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.gold,
                  )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _AvatarSheet extends StatefulWidget {
  const _AvatarSheet({required this.user});

  final UserProfile user;

  @override
  State<_AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends State<_AvatarSheet> {
  late String? _selected = widget.user.avatarUrl;

  @override
  Widget build(BuildContext context) {
    // Жижиг дэлгэц дээр агуулга багтахгүй байвал гүйж болно; доод талд
    // системийн заагчийн зай үлдээнэ.
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 26 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Аватар сонгох',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 6),
          Text(
            'Өнгөө сонгоно уу — нэрийн эхний үсэг тань дээр нь харагдана.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            children: avatarPresets.map((p) {
              final isSelected = _selected == p.value;
              return Semantics(
                button: true,
                selected: isSelected,
                label: p.label,
                child: AnimatedPressable(
                  onPressed: () => setState(() => _selected = p.value),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.enter,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.sapphire
                            : Colors.transparent,
                        width: 2.4,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: p.gradient,
                            ),
                            child: Center(
                              child: Text(
                                avatarInitial(widget.user.name),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.sapphire,
                              ),
                              child: const Icon(LucideIcons.check,
                                  size: 11, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Хадгалах',
            icon: LucideIcons.check,
            onPressed: _selected == null || _selected == widget.user.avatarUrl
                ? null
                : () => Navigator.pop(context, _selected),
          ),
        ],
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
          Text('Нэр солих', style: Theme.of(context).textTheme.displayMedium),
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
            child: const Text('Болих', style: TextStyle(color: AppColors.muted)),
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
        _current.text.isEmpty ? 'Одоогийн нууц үгээ оруулна уу' : null;
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
          Text('Нууц үг солих',
              style: Theme.of(context).textTheme.displayMedium),
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
            hint: 'Дор хаяж 8 тэмдэгт',
            error: _nextError,
            enabled: !_loading,
            shakeToken: _shake,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {
              if (_nextError != null) _nextError = Validators.password(_next.text);
              if (_confirmError != null) {
                _confirmError =
                    Validators.confirmPassword(_confirm.text, _next.text);
              }
            }),
          ),
          PasswordStrengthMeter(password: _next.text),
          const SizedBox(height: 14),
          PasswordField(
            label: 'Шинэ нууц үг давтах',
            controller: _confirm,
            hint: 'Дахин оруулна уу',
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
            child: const Text('Болих', style: TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedPressable(
        onPressed: onTap,
        scale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: color ?? AppColors.sapphireSoft),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        color: color ?? AppColors.ink,
                        fontWeight: FontWeight.w600,
                      )),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 17, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
