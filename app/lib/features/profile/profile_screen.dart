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
                  16,
                  8,
                  16,
                  Breakpoints.isWide(context)
                      ? 40
                      : NavMetrics.bottomInset(context)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                  child: Text('Профайл',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                _Header(
                  user: user,
                  onTap: () => _editName(context, ref, user.name),
                ),
                const SizedBox(height: 28),
                GroupSection(dividerInset: 57, children: [
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.gem, color: _tileGreen),
                    title: 'Миний эрх',
                    value: '${user.balance} эрх',
                    onTap: () => context.push('/wallet'),
                  ),
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.trophy, color: _tileOrange),
                    title: 'Хожсон бараа',
                    trailing: due > 0 ? _Badge(count: due) : null,
                    onTap: () => context.push('/orders'),
                  ),
                ]),
                const SizedBox(height: 28),
                GroupSection(title: 'Бүртгэл', dividerInset: 57, children: [
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.userPen, color: _tileBlue),
                    title: 'Нэр солих',
                    onTap: () => _editName(context, ref, user.name),
                  ),
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.palette, color: _tileOrange),
                    title: 'Аватар солих',
                    onTap: () => _editAvatar(context, ref, user),
                  ),
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.keyRound, color: _tileGray),
                    title: 'Нууц үг солих',
                    onTap: () => _changePassword(context, ref),
                  ),
                ]),
                const SizedBox(height: 28),
                GroupSection(title: 'Тусламж', dividerInset: 57, children: [
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.lifeBuoy, color: _tileBlue),
                    title: 'Тусламж',
                    onTap: () => context.push('/help'),
                  ),
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.messageSquare, color: _tileGreen),
                    title: 'Санал хүсэлт',
                    onTap: () => context.push('/feedback'),
                  ),
                ]),
                const SizedBox(height: 28),
                GroupSection(title: 'Нөхцөл', dividerInset: 57, children: [
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.fileText, color: _tileGray),
                    title: 'Үйлчилгээний нөхцөл',
                    onTap: () => context.push('/content/terms'),
                  ),
                  GroupRow(
                    leading: const IconTile(
                        icon: LucideIcons.shieldCheck, color: _tileGray),
                    title: 'Нууцлалын бодлого',
                    onTap: () => context.push('/content/privacy'),
                  ),
                ]),
                const SizedBox(height: 28),
                GroupSection(children: [
                  Semantics(
                    button: true,
                    label: 'Гарах',
                    child: AnimatedPressable(
                      onPressed: () => _logout(context, ref),
                      scale: 0.99,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        color: Colors.transparent,
                        child: Text('Гарах',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w400,
                                color: AppColors.danger)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: Text('E-Duud 0.1.0',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
            Text('Гарах уу?',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Дахин орохдоо нэвтэрнэ.',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Гарах',
              icon: LucideIcons.logOut,
              gradient: AppColors.dangerGradient,
              foreground: Colors.white,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Болих',
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

// iOS system өнгөнүүд — icon tile дээр цагаан дүрстэй хослоно.
const _tileGreen = Color(0xFF34C759);
const _tileBlue = Color(0xFF007AFF);
const _tileOrange = Color(0xFFFF9500);
const _tileGray = Color(0xFF8E8E93);

/// Толгой карт — аватар, нэр, утас; дарвал нэр засна.
class _Header extends StatelessWidget {
  const _Header({required this.user, required this.onTap});

  final UserProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GroupSection(children: [
      GroupRow(
        minHeight: 84,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: AppAvatar(name: user.name, avatarUrl: user.avatarUrl, size: 60),
        title: user.name,
        subtitle: user.isAdmin ? '${user.phone} · Админ' : user.phone,
        onTap: onTap,
      ),
    ]);
  }
}

/// Төлөх хүлээж буй барааны тоо — улаан дугуй.
class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text('$count',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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
          Text('Нэр солих',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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
                Text('Болих', style: TextStyle(color: AppColors.inkSoft)),
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
          Text('Нууц үг солих',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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
                Text('Болих', style: TextStyle(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}
