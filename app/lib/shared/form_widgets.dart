import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import 'validators.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// Хөдөлгөөний туслах
// ---------------------------------------------------------------------------

/// `token` өөрчлөгдөх бүрд хажуу тийш сэгсэрнэ. Алдааг өнгөнөөс гадна
/// хөдөлгөөнөөр давхар мэдэгдэх зорилготой.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.token, required this.child});

  final int token;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token &&
        widget.token > 0 &&
        !reducedMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (_c.value == 0 || _c.isCompleted) return child!;
        // Далайц нь буурч байгаа синус — жинхэнэ "сэгсрэлт" мэт.
        final decay = 1 - _c.value;
        final dx = 9 * decay * (1 - 2 * ((_c.value * 4) % 1 - 0.5).abs() * 2);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Талбар
// ---------------------------------------------------------------------------

/// Нэгдсэн маягтын талбар: харагдах лэйбл, алдааны төлөв, туслах текст.
///
/// Алдааг заавал icon + текстээр хамт харуулна — өнгөөр дангаар нь мэдээлэл
/// дамжуулахгүй.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.helper,
    this.icon,
    this.suffix,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.shakeToken = 0,
    this.invalid = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;

  /// Тухайн талбарт өөрийн гэсэн мессеж байхгүй ч алдаатай гэж тэмдэглэнэ —
  /// жиш. "дугаар эсвэл нууц үг буруу" үед аль аль нь улаан болно.
  final bool invalid;
  final String? helper;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final List<String>? autofillHints;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final int shakeToken;
  final TextCapitalization textCapitalization;

  /// iOS маяг: хүрээгүй (width 0 → transparent), фокуст accent 1.5px.
  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final hasError = error != null || invalid;
    final accent = hasError ? AppColors.danger : AppColors.coral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasError ? AppColors.dangerSoft : AppColors.inkSoft,
            ),
          ),
        ),
        Shake(
          token: shakeToken,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            maxLines: obscureText ? 1 : maxLines,
            minLines: minLines,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: AppColors.ink),
            cursorColor: accent,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              counterText: '',
              filled: true,
              fillColor: hasError
                  ? AppColors.dangerBg
                  : AppColors.fill,
              prefixIcon: icon == null
                  ? null
                  : Icon(icon,
                      size: 20,
                      color: hasError ? AppColors.dangerSoft : AppColors.muted),
              suffixIcon: suffix,
              enabledBorder: _border(AppColors.danger, hasError ? 1.2 : 0),
              focusedBorder: _border(accent, 1.5),
              border: _border(AppColors.danger, hasError ? 1.2 : 0),
              disabledBorder: _border(AppColors.border, 0),
            ),
          ),
        ),
        FieldMessage(error: error, helper: helper),
      ],
    );
  }
}

/// Талбарын доод мөр: алдаа байвал улаанаар, эс бөгөөс туслах текст.
class FieldMessage extends StatelessWidget {
  const FieldMessage({super.key, this.error, this.helper});

  final String? error;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final text = error ?? helper;
    final isError = error != null;

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      alignment: Alignment.topLeft,
      child: text == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Semantics(
              liveRegion: isError,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, top: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isError ? LucideIcons.circleAlert : LucideIcons.info,
                      size: 13,
                      color: isError ? AppColors.dangerSoft : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: isError
                              ? AppColors.dangerSoft
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Нууц үгийн талбар — харах/нуух товчтой.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.shakeToken = 0,
    this.invalid = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final int shakeToken;
  final bool invalid;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AppField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      error: widget.error,
      helper: widget.helper,
      icon: LucideIcons.lock,
      obscureText: _obscure,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      shakeToken: widget.shakeToken,
      invalid: widget.invalid,
      suffix: Semantics(
        button: true,
        label: _obscure ? 'Нууц үгийг харуулах' : 'Нууц үгийг нуух',
        child: IconButton(
          icon: Icon(_obscure ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 18, color: AppColors.muted),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Нууц үгийн бат бөх байдлын 4 сегмент бүхий заагч.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final s = PasswordStrength.of(password);

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      alignment: Alignment.topLeft,
      child: s.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(4, (i) {
                      final filled = i < s.level;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 5),
                          child: AnimatedContainer(
                            duration: AppMotion.base,
                            curve: AppMotion.enter,
                            height: 5,
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.strength[s.level - 1]
                                  : AppColors.borderHi,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 7),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      children: [
                        Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.strength[s.level - 1],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Маягтын дээд талын нэгдсэн алдаа (жиш. "дугаар эсвэл нууц үг буруу").
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, this.message, this.shakeToken = 0});

  final String? message;
  final int shakeToken;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity, height: 0)
          : Shake(
              token: shakeToken,
              child: Semantics(
                liveRegion: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.triangleAlert,
                          size: 16, color: AppColors.dangerSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message!,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dangerSoft,
                          ),
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

// ---------------------------------------------------------------------------
// OTP
// ---------------------------------------------------------------------------

/// 6 нүдтэй код оруулах талбар.
///
/// Нүд бүрд тусдаа controller өгөхийн оронд нэг далд TextField-ийн утгыг
/// зурдаг — фокус үсрэх, backspace алдагдах зэрэг эмзэг байдал үүсэхгүй.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = Validators.otpLength,
    this.hasError = false,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool hasError;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final _focus = FocusNode();

  /// Сүүлд боловсруулсан утга. `onCompleted` нэг кодод яг нэг л удаа
  /// дуудагдахыг баталгаажуулна — эс бөгөөс код давхар шалгагдана.
  String _lastValue = '';

  @override
  void initState() {
    super.initState();
    _lastValue = widget.controller.text;
    widget.controller.addListener(_onText);
    _focus.addListener(_repaint);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_repaint);
    _focus.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _onText() {
    if (!mounted) return;
    final v = widget.controller.text;
    if (v == _lastValue) return;

    final wasFull = _lastValue.length == widget.length;
    _lastValue = v;

    setState(() {});
    widget.onChanged?.call(v);

    // Зөвхөн дүүрэн болох агшинд нэг удаа.
    if (v.length == widget.length && !wasFull) {
      FocusScope.of(context).unfocus();
      widget.onCompleted?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final focused = _focus.hasFocus;

    return Semantics(
      label: 'Баталгаажуулах код, ${widget.length} орон',
      textField: true,
      child: Stack(
        children: [
          Row(
            children: List.generate(widget.length, (i) {
              final filled = i < value.length;
              final isNext = focused && i == value.length;
              final borderColor = widget.hasError
                  ? AppColors.danger
                  : isNext
                      ? AppColors.coral
                      : filled
                          ? AppColors.borderHi
                          : AppColors.border;

              return Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i == widget.length - 1 ? 0 : 10),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.enter,
                    height: 68,
                    decoration: BoxDecoration(
                      color: widget.hasError
                          ? AppColors.dangerBg
                          : AppColors.fill,
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                      border: Border.all(
                          color: isNext || widget.hasError
                              ? borderColor
                              : Colors.transparent,
                          width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: filled
                        ? TweenAnimationBuilder<double>(
                            key: ValueKey('$i-${value[i]}'),
                            tween: Tween(
                                begin: reducedMotion(context) ? 1 : 0.5,
                                end: 1),
                            duration: AppMotion.base,
                            curve: Curves.easeOutBack,
                            builder: (context, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: Text(
                              value[i],
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          )
                        : Container(
                            width: 10,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.muted.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
          // Хараагүй боловч бодит талбар — товшилт, гар, SMS autofill энд очно.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                showCursor: false,
                enableInteractiveSelection: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Сонголт
// ---------------------------------------------------------------------------

class ChipOption<T> {
  const ChipOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Хэд хэдэн сонголтоос нэгийг сонгох чипс. Радио товчлуураас илүү нягт,
/// гар утсанд хүрэхэд тохиромжтой (доод тал нь 44pt өндөр).
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<ChipOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = o.value == selected;
        return Semantics(
          button: true,
          selected: isSelected,
          label: o.label,
          child: AnimatedPressable(
            onPressed: () => onSelected(o.value),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.enter,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.14)
                    : AppColors.fill,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                border: Border.all(
                    color: isSelected ? AppColors.accent : Colors.transparent,
                    width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.icon != null) ...[
                    Icon(o.icon,
                        size: 15,
                        color:
                            isSelected ? AppColors.coral : AppColors.inkSoft),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    o.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppColors.ink : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Тест орчны тэмдэглэгээ
// ---------------------------------------------------------------------------

/// Зөвхөн тест орчинд харагдах самбар. Жинхэнэ өгөгдөлтэй андуурахгүйн тулд
/// улбар шар өнгө + колбоны icon-той, үргэлж "Тест орчин" гэж бичнэ.
class TestModeCard extends StatelessWidget {
  const TestModeCard({
    super.key,
    required this.title,
    this.value,
    this.description,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String? value;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.flaskConical,
                  size: 15, color: AppColors.warn),
              const SizedBox(width: 8),
              Text(
                'Тест орчин',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warn.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
          if (value != null) ...[
            const SizedBox(height: 10),
            SelectableText(
              value!,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 8,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: TextStyle(
                  fontSize: 12, height: 1.45, color: AppColors.muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            AnimatedPressable(
              onPressed: loading ? null : onAction,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.warn.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border:
                      Border.all(color: AppColors.warn.withValues(alpha: 0.5)),
                ),
                child: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: AppColors.warn),
                      )
                    : Text(
                        actionLabel!,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warn,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
