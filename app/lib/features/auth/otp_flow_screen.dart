import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/form_widgets.dart';
import '../../shared/validators.dart';
import '../../shared/widgets.dart';
import 'auth_controller.dart';
import 'auth_shell.dart';

/// Бүртгүүлэх (purpose=register) ба нууц үг сэргээх (purpose=reset) нэг урсгал:
/// 1. дугаар → OTP илгээх, 2. код шалгах → ticket, 3. нэр/нууц үг.
class OtpFlowScreen extends ConsumerStatefulWidget {
  const OtpFlowScreen({super.key, required this.purpose, this.next});

  final String purpose; // register | reset

  /// Бүртгэл амжилттай бол очих зам (landing/auction-оос ирсэн бол).
  final String? next;

  @override
  ConsumerState<OtpFlowScreen> createState() => _OtpFlowScreenState();
}

class _OtpFlowScreenState extends ConsumerState<OtpFlowScreen> {
  static const _resendSeconds = 60;

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  int _step = 0;
  bool _loading = false;
  String? _ticket;
  String? _devCode;
  int _shake = 0;

  String? _formError;
  String? _phoneError;
  String? _codeError;
  String? _nameError;
  String? _passwordError;
  String? _confirmError;

  bool _nameTouched = false;
  bool _passwordTouched = false;
  bool _confirmTouched = false;

  Timer? _resendTimer;
  int _resendIn = 0;

  bool get _isRegister => widget.purpose == 'register';

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in [_phone, _code, _name, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_phoneFocus, _nameFocus, _passwordFocus, _confirmFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn -= 1);
      if (_resendIn <= 0) t.cancel();
    });
  }

  /// Сүлжээний дуудлагыг нэг дор боож, алдааг баннерт гаргана.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() {
          _formError = apiErrorMessage(e);
          _shake++;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- 1. Дугаар ----------

  Future<void> _sendOtp({bool resend = false}) async {
    if (_loading) return;
    final error = Validators.phone(_phone.text);
    setState(() => _phoneError = error);
    if (error != null) {
      setState(() => _shake++);
      _phoneFocus.requestFocus();
      return;
    }

    await _run(() async {
      final devCode = await ref
          .read(authProvider.notifier)
          .requestOtp(_phone.text.trim(), widget.purpose);
      if (!mounted) return;
      setState(() {
        _devCode = devCode;
        _codeError = null;
        if (!resend) _step = 1;
        if (resend) _code.clear();
      });
      _startResendCountdown();
    });
  }

  // ---------- 2. Код ----------

  Future<void> _verifyOtp() async {
    // OTP нэг л удаа хэрэглэгддэг: давхар дуудвал хоёр дахь нь "код хүчингүй"
    // гэсэн худал алдаа болно.
    if (_loading || _ticket != null) return;
    final error = Validators.otp(_code.text);
    setState(() => _codeError = error);
    if (error != null) {
      setState(() => _shake++);
      return;
    }

    await _run(() async {
      final ticket = await ref
          .read(authProvider.notifier)
          .verifyOtp(_phone.text.trim(), widget.purpose, _code.text.trim());
      if (!mounted) return;
      setState(() {
        _ticket = ticket;
        _step = 2;
      });
    });
  }

  // ---------- 3. Дуусгах ----------

  void _revalidateFinal() {
    setState(() {
      if (_nameTouched) _nameError = Validators.name(_name.text);
      if (_passwordTouched) {
        _passwordError = Validators.password(_password.text);
      }
      if (_confirmTouched) {
        _confirmError =
            Validators.confirmPassword(_confirm.text, _password.text);
      }
    });
  }

  Future<void> _finish() async {
    if (_loading) return;
    final nameError = _isRegister ? Validators.name(_name.text) : null;
    final passwordError = Validators.password(_password.text);
    final confirmError =
        Validators.confirmPassword(_confirm.text, _password.text);

    setState(() {
      _nameTouched = true;
      _passwordTouched = true;
      _confirmTouched = true;
      _nameError = nameError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });

    if (nameError != null || passwordError != null || confirmError != null) {
      setState(() => _shake++);
      if (nameError != null) {
        _nameFocus.requestFocus();
      } else if (passwordError != null) {
        _passwordFocus.requestFocus();
      } else {
        _confirmFocus.requestFocus();
      }
      return;
    }

    await _run(() async {
      if (_isRegister) {
        await ref
            .read(authProvider.notifier)
            .register(_ticket!, _name.text.trim(), _password.text);
        if (!mounted) return;
        final next = widget.next;
        context.go(next != null && next.startsWith('/') ? next : '/');
      } else {
        await ref
            .read(authProvider.notifier)
            .resetPassword(_ticket!, _password.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нууц үг солигдлоо. Одоо нэвтэрнэ үү.')),
        );
        context.go('/auth/login');
      }
    });
  }

  void _back() {
    if (_loading) return;
    if (_step > 0) {
      setState(() {
        _step -= 1;
        _formError = null;
        // Кодын алхам руу буцвал ticket хүчингүй болгож, шинэ код оруулах
        // боломж нээнэ (хуучин код аль хэдийн ашиглагдсан).
        if (_step == 1) {
          _ticket = null;
          _code.clear();
          _codeError = null;
        }
      });
    } else if (context.canPop()) {
      context.pop();
    } else {
      // Web дээр URL-аар шууд орж ирсэн — буцах түүх байхгүй.
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: AuthShell(
          backEnabled: !_loading,
          onBack: _back,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Steps(step: _step, isRegister: _isRegister),
              const SizedBox(height: 24),
              // Алхам солигдоход агуулга зөөлөн солигдоно.
              AnimatedSwitcher(
                duration: AppMotion.base,
                switchInCurve: AppMotion.enter,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0.05, 0), end: Offset.zero)
                            .animate(anim),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previous,
                    if (current != null) current,
                  ],
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) => switch (_step) {
        0 => _phoneStep(context),
        1 => _codeStep(context),
        _ => _finalStep(context),
      };

  Widget _header(BuildContext context, String title, String subtitle) =>
      AuthHeading(title: title, subtitle: subtitle);

  Widget _phoneStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          _isRegister ? 'Бүртгүүлэх' : 'Нууц үг сэргээх',
          _isRegister
              ? 'Утасны дугаараа оруулна уу. Бид баталгаажуулах код илгээнэ.'
              : 'Бүртгэлтэй дугаараа оруулна уу. Бид баталгаажуулах код илгээнэ.',
        ),
        ErrorBanner(message: _formError, shakeToken: _shake),
        AppField(
          label: 'Утасны дугаар',
          controller: _phone,
          focusNode: _phoneFocus,
          hint: '99xxxxxx',
          icon: LucideIcons.smartphone,
          error: _phoneError,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          maxLength: Validators.phoneLength,
          enabled: !_loading,
          shakeToken: _shake,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(Validators.phoneLength),
          ],
          onChanged: (_) {
            if (_phoneError != null) {
              setState(() => _phoneError = Validators.phone(_phone.text));
            }
          },
          onSubmitted: (_) => _sendOtp(),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Код авах',
          loading: _loading,
          onPressed: _loading ? null : _sendOtp,
        ),
      ],
    );
  }

  Widget _codeStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          'Кодоо оруулна уу',
          '${_phone.text} дугаарт 6 оронтой код илгээлээ.',
        ),
        ErrorBanner(message: _formError, shakeToken: _shake),
        Shake(
          token: _shake,
          child: OtpInput(
            controller: _code,
            hasError: _codeError != null,
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            onCompleted: (_) => _verifyOtp(),
          ),
        ),
        FieldMessage(error: _codeError),
        if (_devCode != null) ...[
          const SizedBox(height: 18),
          TestModeCard(
            title: 'Код SMS-ээр явсангүй. Доорх кодыг ашиглана уу.',
            value: _devCode,
            description: 'Энэ самбар зөвхөн тест орчинд гарна.',
            actionLabel: 'Кодыг оруулах',
            onAction: () {
              _code.text = _devCode!;
              setState(() => _codeError = null);
            },
          ),
        ],
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Баталгаажуулах',
          loading: _loading,
          onPressed: _loading ? null : _verifyOtp,
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: (_loading || _resendIn > 0)
                ? null
                : () => _sendOtp(resend: true),
            child: Text(
              _resendIn > 0
                  ? 'Дахин код авах ($_resendIn сек)'
                  : 'Дахин код авах',
              style: TextStyle(
                color: _resendIn > 0 ? AppColors.muted : AppColors.accent,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _finalStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          _isRegister ? 'Нэр, нууц үгээ оруулна уу' : 'Шинэ нууц үг',
          _isRegister
              ? 'Дараа нь шууд оролцож эхэлнэ.'
              : 'Нууц үг солигдсоны дараа бүх төхөөрөмжөөс гарна.',
        ),
        ErrorBanner(message: _formError, shakeToken: _shake),
        if (_isRegister) ...[
          AppField(
            label: 'Нэр',
            controller: _name,
            focusNode: _nameFocus,
            hint: 'Таныг хэн гэж дуудах вэ?',
            icon: LucideIcons.user,
            error: _nameError,
            enabled: !_loading,
            shakeToken: _shake,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            maxLength: Validators.nameMax,
            onChanged: (_) => _revalidateFinal(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
        ],
        PasswordField(
          label: _isRegister ? 'Нууц үг' : 'Шинэ нууц үг',
          controller: _password,
          focusNode: _passwordFocus,
          hint: 'Дор хаяж 8 тэмдэгт',
          error: _passwordError,
          enabled: !_loading,
          shakeToken: _shake,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => _revalidateFinal(),
          onSubmitted: (_) => _confirmFocus.requestFocus(),
        ),
        PasswordStrengthMeter(password: _password.text),
        const SizedBox(height: 16),
        PasswordField(
          label: 'Нууц үг давтах',
          controller: _confirm,
          focusNode: _confirmFocus,
          hint: 'Дахин оруулна уу',
          error: _confirmError,
          helper: _confirmMatchHint,
          enabled: !_loading,
          shakeToken: _shake,
          textInputAction: TextInputAction.done,
          onChanged: (_) => _revalidateFinal(),
          onSubmitted: (_) => _finish(),
        ),
        const SizedBox(height: 26),
        PrimaryButton(
          label: _isRegister ? 'Бүртгүүлэх' : 'Нууц үг хадгалах',
          loading: _loading,
          onPressed: _loading ? null : _finish,
        ),
      ],
    );
  }

  /// Хоёр нууц үг таарсныг эерэгээр баталгаажуулна.
  String? get _confirmMatchHint {
    if (_confirm.text.isEmpty || _confirmError != null) return null;
    if (_confirm.text == _password.text) return 'Нууц үг таарч байна';
    return null;
  }
}

/// Алхмын заагч: "1/3" жижиг тайлбар + нимгэн гурван хэсэгт зурвас.
class _Steps extends StatelessWidget {
  const _Steps({required this.step, required this.isRegister});

  final int step;
  final bool isRegister;

  @override
  Widget build(BuildContext context) {
    final labels = ['Утас', 'Код', isRegister ? 'Нэр, нууц үг' : 'Нууц үг'];
    return Semantics(
      label: '${step + 1}-р алхам, нийт ${labels.length}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.base,
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.accent : AppColors.fill,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${step + 1}/${labels.length} · ${labels[step]}',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
