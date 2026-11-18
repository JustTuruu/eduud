import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../features/home/auction_timing.dart';
import 'widgets.dart' show reducedMotion;

/// Дуудлагын тоолуур: `mm:ss.SSS`. Кадр бүрт зөвхөн энэ жижиг Text дахин
/// зурагдана (Ticker), эцэг widget-ийг rebuild хийхгүй. ".SSS" хэсэг арай
/// жижиг, бүдэгхэн. Үлдсэн хугацаа ≤ 0 болмогц ticker зогсоно.
class LiveCountdownText extends StatefulWidget {
  const LiveCountdownText({
    super.key,
    required this.endsAt,
    this.serverOffsetMs = 0,
    required this.style,
    this.urgentColor,
    this.urgentBelow = const Duration(seconds: 10),
    this.onFinished,
  });

  final DateTime endsAt;
  final int serverOffsetMs;
  final TextStyle style;

  /// Үлдсэн хугацаа `urgentBelow`-оос бага үед ашиглах өнгө (null бол үндсэн).
  final Color? urgentColor;
  final Duration urgentBelow;
  final VoidCallback? onFinished;

  @override
  State<LiveCountdownText> createState() => _LiveCountdownTextState();
}

class _LiveCountdownTextState extends State<LiveCountdownText>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _left = Duration.zero;
  Duration _lastPaint = Duration.zero;
  bool _finishedFired = false;
  bool _throttle = false;

  Duration _compute() => widget.endsAt.difference(
      DateTime.now().add(Duration(milliseconds: widget.serverOffsetMs)));

  @override
  void initState() {
    super.initState();
    _left = _compute();
    if (_left.inMilliseconds > 0) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant LiveCountdownText old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt ||
        old.serverOffsetMs != widget.serverOffsetMs) {
      _finishedFired = false;
      _left = _compute();
      if (_left.inMilliseconds > 0 && !_ticker.isActive) _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _throttle = reducedMotion(context);
  }

  void _onTick(Duration elapsed) {
    // reducedMotion үед ~10 Гц-ээр шинэчилнэ (мэдээлэл, анимаци биш).
    if (_throttle && elapsed - _lastPaint < const Duration(milliseconds: 100)) {
      return;
    }
    _lastPaint = elapsed;
    final left = _compute();
    setState(() => _left = left);
    if (left.inMilliseconds <= 0) {
      _ticker.stop();
      if (!_finishedFired) {
        _finishedFired = true;
        widget.onFinished?.call();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urgent = widget.urgentColor != null &&
        _left.inMilliseconds > 0 &&
        _left < widget.urgentBelow;
    final base = widget.style.copyWith(
      color: urgent ? widget.urgentColor : widget.style.color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = formatRemainingMs(_left);
    final dot = text.lastIndexOf('.');
    final fade = base.copyWith(
      fontSize: (base.fontSize ?? 14) * 0.7,
      color: (base.color ?? Colors.black).withValues(alpha: 0.7),
    );
    return RepaintBoundary(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: text.substring(0, dot), style: base),
          TextSpan(text: text.substring(dot), style: fade),
        ]),
        maxLines: 1,
      ),
    );
  }
}
