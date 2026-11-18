import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import 'widgets.dart';

enum TopToastKind { info, success, error }

/// Дээрээс гулсан орж ирдэг iOS маягийн мэдэгдэл.
///
/// Дүрэм: нэг зэрэг ганцхан toast — дараалал байхгүй. Шинэ мессеж өмнөхийг
/// шууд солино; ижил мессеж харагдаж байвал зөвхөн хугацааг нь шинэчилнэ.
/// Root Overlay дээр зурагдах тул sheet, tab bar-ын дээгүүр харагдана.
void showTopToast(
  BuildContext context,
  String message, {
  TopToastKind kind = TopToastKind.info,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final cur = _current;
  if (cur != null && cur.message == message && cur.entry.mounted) {
    cur.key.currentState?.restart();
    return;
  }
  _dismissNow();

  final key = GlobalKey<_TopToastState>();
  late final _Active active;
  final entry = OverlayEntry(
    builder: (_) => _TopToast(
      key: key,
      message: message,
      kind: kind,
      onDone: () {
        if (identical(_current, active)) _current = null;
        if (active.entry.mounted) active.entry.remove();
        active.entry.dispose();
      },
    ),
  );
  active = _Active(entry, key, message);
  _current = active;
  overlay.insert(entry);
}

class _Active {
  _Active(this.entry, this.key, this.message);
  final OverlayEntry entry;
  final GlobalKey<_TopToastState> key;
  final String message;
}

_Active? _current;

void _dismissNow() {
  final cur = _current;
  _current = null;
  if (cur == null) return;
  if (cur.entry.mounted) cur.entry.remove();
  cur.entry.dispose();
}

class _TopToast extends StatefulWidget {
  const _TopToast({
    super.key,
    required this.message,
    required this.kind,
    required this.onDone,
  });

  final String message;
  final TopToastKind kind;
  final VoidCallback onDone;

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  static const _visible = Duration(milliseconds: 2200);

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  Timer? _timer;
  double _drag = 0;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    _timer = Timer(_visible, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void restart() {
    if (_closing) return;
    _timer?.cancel();
    _timer = Timer(_visible, _close);
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    try {
      await _ctrl.reverse();
    } catch (_) {}
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    final top = MediaQuery.of(context).padding.top;
    final color = switch (widget.kind) {
      TopToastKind.success => AppColors.accent,
      TopToastKind.error => AppColors.danger,
      TopToastKind.info => AppColors.inkSoft,
    };
    final icon = switch (widget.kind) {
      TopToastKind.success => LucideIcons.circleCheck,
      TopToastKind.error => LucideIcons.circleAlert,
      TopToastKind.info => LucideIcons.info,
    };
    final curved = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    Widget capsule = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    capsule = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      onVerticalDragUpdate: (d) =>
          setState(() => _drag = (_drag + d.delta.dy).clamp(-120.0, 8.0)),
      onVerticalDragEnd: (d) {
        if (_drag < -24 || (d.primaryVelocity ?? 0) < -300) {
          _close();
        } else {
          setState(() => _drag = 0);
        }
      },
      child: capsule,
    );

    return Positioned(
      top: top + 8,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: Semantics(
          liveRegion: true,
          container: true,
          label: widget.message,
          child: AnimatedBuilder(
            animation: curved,
            builder: (context, child) {
              final t = curved.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, reduce ? _drag : (1 - t) * -80 + _drag),
                  child: child,
                ),
              );
            },
            child: Material(type: MaterialType.transparency, child: capsule),
          ),
        ),
      ),
    );
  }
}
