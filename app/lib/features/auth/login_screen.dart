import 'package:dio/dio.dart';
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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Нэвтэрсний дараа очих зам (жиш. санал өгөх гэж байсан auction).
  final String? next;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading = false;

  String? _phoneError;
  String? _passwordError;

  /// Дугаар/нууц үгийн аль нь буруу болохыг сервер зориудаар хэлдэггүй
  /// (дугаар бүртгэлтэй эсэхийг таах боломж олгохгүй) — тиймээс нэгдсэн banner.
  String? _formError;

  /// 401 үед хоёр талбар хоёулаа улаан хүрээтэй болно; тайлбарыг banner хэлнэ.
  bool _credentialsInvalid = false;

  /// Талбар нэг удаа алдаа өгсний дараа бичих бүрд шууд шалгаж эхэлнэ.
  bool _phoneTouched = false;
  bool _passwordTouched = false;

  int _shake = 0;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _revalidate() {
    setState(() {
      if (_phoneTouched) _phoneError = Validators.phone(_phone.text);
      if (_passwordTouched) {
        _passwordError = Validators.loginPassword(_password.text);
      }
    });
  }

  Future<void> _submit() async {
    final phoneError = Validators.phone(_phone.text);
    final passwordError = Validators.loginPassword(_password.text);

    setState(() {
      _phoneTouched = true;
      _passwordTouched = true;
      _phoneError = phoneError;
      _passwordError = passwordError;
      _formError = null;
      _credentialsInvalid = false;
    });

    if (phoneError != null || passwordError != null) {
      setState(() => _shake++);
      // Эхний алдаатай талбар руу фокус — хэрэглэгч хайх шаардлагагүй.
      (phoneError != null ? _phoneFocus : _passwordFocus).requestFocus();
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .login(_phone.text.trim(), _password.text);
      if (mounted) context.go(_target);
    } catch (e) {
      if (!mounted) return;
      final status = e is DioException ? e.response?.statusCode : null;
      setState(() {
        _loading = false;
        _shake++;
        if (status == 401) {
          // Хоёулангийнх нь хүрээг улаан болгож, шалтгааныг дээр нь тайлбарлана.
          _formError =
              'Утасны дугаар эсвэл нууц үг буруу байна. Дахин шалгана уу.';
          _credentialsInvalid = true;
        } else {
          _formError = apiErrorMessage(e);
        }
      });
    }
  }

  String get _target => (widget.next != null && widget.next!.startsWith('/'))
      ? widget.next!
      : '/';

  /// Бүртгүүлэх/мартсан руу шилжихдээ `next`-ийг хадгална.
  String _withNext(String path) => widget.next == null
      ? path
      : Uri(path: path, queryParameters: {'next': widget.next}).toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthShell(
        backEnabled: !_loading,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeading(
                title: 'Нэвтрэх',
                subtitle:
                    'Санал өгөх, эрхээ цэнэглэх, хожсон бараагаа авахын тулд нэвтэрнэ үү.',
              ),
              ErrorBanner(message: _formError, shakeToken: _shake),
              AppField(
                label: 'Утасны дугаар',
                controller: _phone,
                focusNode: _phoneFocus,
                hint: '99xxxxxx',
                icon: LucideIcons.smartphone,
                error: _phoneError,
                invalid: _credentialsInvalid,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                maxLength: Validators.phoneLength,
                enabled: !_loading,
                shakeToken: _shake,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(Validators.phoneLength),
                ],
                onChanged: (_) {
                  _clearFormError();
                  _revalidate();
                },
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 20),
              PasswordField(
                label: 'Нууц үг',
                controller: _password,
                focusNode: _passwordFocus,
                hint: 'Нууц үгээ оруулна уу',
                error: _passwordError,
                invalid: _credentialsInvalid,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enabled: !_loading,
                shakeToken: _shake,
                onChanged: (_) {
                  _clearFormError();
                  _revalidate();
                },
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed:
                      _loading ? null : () => context.push('/auth/forgot'),
                  child: const Text(
                    'Нууц үгээ мартсан уу?',
                    style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Нэвтрэх',
                icon: LucideIcons.logIn,
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: 28),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Шинэ хэрэглэгч үү?',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.inkSoft)),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => context.push(_withNext('/auth/register')),
                    child: const Text(
                      'Бүртгүүлэх',
                      style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearFormError() {
    if (_formError != null) {
      setState(() {
        _formError = null;
        _credentialsInvalid = false;
      });
    }
  }
}
