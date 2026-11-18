import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// Зургийг "Peek" маягаар томруулна: бүтэн дэлгэц биш, арын хуудас бүдэг
/// харагдсан хэвээр, дундаа хөвөх карт. Backdrop/× дарж эсвэл доош чирж хаана.
Future<void> showImagePeek(BuildContext context,
    {required List<String> images,
    int initial = 0,
    ImageProvider Function(String url)? providerFor}) {
  final reduce = reducedMotion(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Хаах',
    barrierColor: Colors.transparent,
    transitionDuration:
        reduce ? Duration.zero : const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) =>
        ImagePeek(images: images, initial: initial, providerFor: providerFor),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class ImagePeek extends StatefulWidget {
  const ImagePeek({
    super.key,
    required this.images,
    this.initial = 0,
    this.providerFor,
  });

  final List<String> images;
  final int initial;

  /// Тестэд сүлжээгүй provider өгөхөд. Өгөхгүй бол NetworkImage.
  final ImageProvider Function(String url)? providerFor;

  @override
  State<ImagePeek> createState() => _ImagePeekState();
}

class _ImagePeekState extends State<ImagePeek> {
  late final PageController _pages =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  double _dy = 0;
  bool _dragging = false;
  bool _zoomed = false;

  /// Зураг бүрийн жинхэнэ харьцаа (өргөн / өндөр); ачаалагдтал байхгүй.
  final Map<int, double> _aspects = {};
  final List<(ImageStream, ImageStreamListener)> _streams = [];

  ImageProvider _provider(String url) =>
      widget.providerFor?.call(url) ?? NetworkImage(url);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAll());
  }

  /// Зураг бүрийн хэмжээг ImageStream-ээр урьдчилан авна.
  void _resolveAll() {
    if (!mounted) return;
    final cfg = createLocalImageConfiguration(context);
    for (var i = 0; i < widget.images.length; i++) {
      final stream = _provider(widget.images[i]).resolve(cfg);
      late final ImageStreamListener l;
      l = ImageStreamListener((info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted && w > 0 && h > 0) setState(() => _aspects[i] = w / h);
      }, onError: (_, __) {
        if (mounted) setState(() => _aspects[i] = 1);
      });
      stream.addListener(l);
      _streams.add((stream, l));
    }
  }

  @override
  void dispose() {
    for (final (s, l) in _streams) {
      s.removeListener(l);
    }
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context, rootNavigator: true).maybePop();

  /// Page-ийн мөрдлөгөөр хоёр зургийн харьцааг холиж, шудрах үед карт жигд өөрчлөгдөнө.
  double _currentAspect(double page) {
    double at(int i) => _aspects[i.clamp(0, widget.images.length - 1)] ?? 1.0;
    final lo = page.floor();
    final t = page - lo;
    return at(lo) + (at(lo + 1) - at(lo)) * t;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduce = reducedMotion(context);
    final multi = widget.images.length > 1;
    final maxW = math.min(900.0, mq.size.width - 32);
    final dotsH = multi ? 40.0 : 0.0;
    final maxH = math.min(mq.size.height * 0.85,
            mq.size.height - mq.padding.top - mq.padding.bottom - 32) -
        dotsH;
    final dim = (1 - (_dy.abs() / 400)).clamp(0.0, 1.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: Opacity(
                opacity: dim,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(color: Colors.black.withAlpha(115)),
                ),
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onVerticalDragStart:
                  _zoomed ? null : (_) => setState(() => _dragging = true),
              onVerticalDragUpdate:
                  _zoomed ? null : (d) => setState(() => _dy += d.delta.dy),
              onVerticalDragEnd: _zoomed
                  ? null
                  : (d) {
                      if (_dy > 120 || (d.primaryVelocity ?? 0) > 700) {
                        _close();
                      } else {
                        setState(() {
                          _dragging = false;
                          _dy = 0;
                        });
                      }
                    },
              child: AnimatedContainer(
                duration: _dragging || reduce
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, math.max(_dy, 0), 0),
                child: Opacity(
                  opacity: dim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pages,
                        builder: (context, _) {
                          final page = _pages.hasClients
                              ? (_pages.page ?? widget.initial.toDouble())
                              : widget.initial.toDouble();
                          final scrolling = (page - page.round()).abs() > 0.001;
                          // Шудрах үед шууд дагана; ачаалж дуусахад 200мс-ээр хөдөлнө.
                          return TweenAnimationBuilder<double>(
                            tween: Tween(end: _currentAspect(page)),
                            duration: scrolling || reduce
                                ? Duration.zero
                                : const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            builder: (context, aspect, _) {
                              var w = maxW;
                              var h = w / aspect;
                              if (h > maxH) {
                                h = maxH;
                                w = h * aspect;
                              }
                              return _card(w, h);
                            },
                          );
                        },
                      ),
                      if (multi) _dots(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(70),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.images.length,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _ZoomPage(
                image: _provider(widget.images[i]),
                onZoomChanged: (z) {
                  if (z != _zoomed) setState(() => _zoomed = z);
                },
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Semantics(
              button: true,
              label: 'Хаах',
              child: GestureDetector(
                onTap: _close,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: 36,
                      height: 36,
                      color: AppColors.surface.withAlpha(150),
                      child:
                          Icon(LucideIcons.x, size: 18, color: AppColors.ink),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Картын гадна, backdrop дээрх хуудасны заагч.
  Widget _dots() {
    final reduce = reducedMotion(context);
    final d = reduce ? Duration.zero : const Duration(milliseconds: 200);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.images.length; i++)
                AnimatedContainer(
                  key: ValueKey('peek-dot-$i'),
                  duration: d,
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: i == _index
                        ? Colors.white
                        : Colors.white.withAlpha(115),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_index + 1} / ${widget.images.length}',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Нэг зураг: pinch-zoom (InteractiveViewer). Томруулсан үед дээд түвшний
/// шудрах/доош чирэх үйлдлийг зөвшөөрөхгүй байхаар `onZoomChanged` мэдэгдэнэ.
class _ZoomPage extends StatefulWidget {
  const _ZoomPage({required this.image, required this.onZoomChanged});

  final ImageProvider image;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _check() => widget.onZoomChanged(_tc.value.getMaxScaleOnAxis() > 1.02);

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _tc,
      minScale: 1,
      maxScale: 4,
      onInteractionUpdate: (_) => _check(),
      onInteractionEnd: (_) => _check(),
      child: Image(
        image: widget.image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(LucideIcons.image, size: 48, color: AppColors.muted),
        ),
      ),
    );
  }
}
