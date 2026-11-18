import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import 'widgets.dart';

/// Бэлэн аватар. Сервер лүү `preset:<id>` гэж хадгалагдана — зураг байршуулах
/// хэрэггүй тул офлайн ч зөв харагдана.
class AvatarPreset {
  const AvatarPreset(this.id, this.label, this.colors);

  final String id;
  final String label;
  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );

  String get value => 'preset:$id';

  /// Нэрийн эхний үсгийн өнгө — цайвар өнгөн дээр бараан, бараан дээр цагаан.
  Color get foreground {
    final avg = Color.lerp(colors.first, colors.last, 0.5)!;
    return avg.computeLuminance() > 0.38
        ? const Color(0xFF1C1C1E)
        : Colors.white;
  }
}

const avatarPresets = <AvatarPreset>[
  AvatarPreset('sapphire', 'Сапфир', [Color(0xFF5B85FF), Color(0xFF3A5FD9)]),
  AvatarPreset('cyan', 'Цэнхэр', [Color(0xFF22D3EE), Color(0xFF0E7490)]),
  AvatarPreset('teal', 'Номин', [Color(0xFF2DD4BF), Color(0xFF0F766E)]),
  AvatarPreset('emerald', 'Ногоон', [Color(0xFF34D399), Color(0xFF047857)]),
  AvatarPreset('lime', 'Шаргал ногоон', [Color(0xFFA3E635), Color(0xFF4D7C0F)]),
  AvatarPreset('amber', 'Хув', [Color(0xFFFBBF24), Color(0xFFB45309)]),
  AvatarPreset('orange', 'Улбар шар', [Color(0xFFFB923C), Color(0xFFC2410C)]),
  AvatarPreset('rose', 'Час улаан', [Color(0xFFFB7185), Color(0xFFBE123C)]),
  AvatarPreset('pink', 'Ягаан', [Color(0xFFF472B6), Color(0xFF9D174D)]),
  AvatarPreset('violet', 'Нил ягаан', [Color(0xFFA78BFA), Color(0xFF6D28D9)]),
  AvatarPreset('indigo', 'Индиго', [Color(0xFF818CF8), Color(0xFF4338CA)]),
  AvatarPreset('slate', 'Саарал', [Color(0xFF94A3B8), Color(0xFF475569)]),
];

AvatarPreset? presetFor(String? avatarUrl) {
  if (avatarUrl == null || !avatarUrl.startsWith('preset:')) return null;
  final id = avatarUrl.substring('preset:'.length);
  for (final p in avatarPresets) {
    if (p.id == id) return p;
  }
  return null;
}

String avatarInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed.characters.first.toUpperCase();
}

/// Аватар. `preset:`, `http(s)://` болон утгагүй — гурван тохиолдлыг зохицуулна.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 44,
  });

  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final preset = presetFor(avatarUrl);
    final isNetwork = avatarUrl != null && avatarUrl!.startsWith('http');

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: preset?.gradient,
        color: preset != null ? null : AppColors.fill,
      ),
      child: isNetwork
          ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _Initial(name: name, size: size, color: AppColors.inkSoft),
            )
          : _Initial(
              name: name,
              size: size,
              color: preset?.foreground ?? AppColors.inkSoft),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.size, required this.color});

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        avatarInitial(name),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1,
        ),
      ),
    );
  }
}

/// Аватар сонгогч — дээр нь сонгосон өнгийг томоор, доор нь дугуй өнгөний тор. Хадгалахад `preset:<id>` утгыг буцаана (sheet-ээс).
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({super.key, required this.name, required this.current});

  final String name;
  final String? current;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  late String? _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Аватар сонгох',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Center(
            child: AnimatedSwitcher(
              duration: reducedMotion(context) ? Duration.zero : AppMotion.base,
              switchInCurve: AppMotion.spring,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: AppAvatar(
                key: ValueKey(_selected),
                name: widget.name,
                avatarUrl: _selected,
                size: 96,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final p in avatarPresets) _swatch(p),
            ],
          ),
          const SizedBox(height: 26),
          PrimaryButton(
            label: 'Хадгалах',
            onPressed: _selected == null || _selected == widget.current
                ? null
                : () => Navigator.pop(context, _selected),
          ),
        ],
      ),
    );
  }

  Widget _swatch(AvatarPreset p) {
    final on = _selected == p.value;
    return Semantics(
      button: true,
      selected: on,
      label: p.label,
      child: AnimatedPressable(
        onPressed: () => setState(() => _selected = p.value),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          width: 52,
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: on ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration:
                BoxDecoration(shape: BoxShape.circle, gradient: p.gradient),
            child: on
                ? Icon(LucideIcons.check, size: 18, color: p.foreground)
                : null,
          ),
        ),
      ),
    );
  }
}
