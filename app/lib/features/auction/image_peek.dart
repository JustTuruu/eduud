import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';

/// Зургийг "Peek" маягаар томруулна: бүтэн дэлгэц биш, арын хуудас бүдэг
/// харагдсан хэвээр, дундаа хөвөх карт. Backdrop/× дарж эсвэл доош чирж хаана.
Future<void> showImagePeek(BuildContext context,
    {required List<String> images, int initial = 0}) {
  final reduce = reducedMotion(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Хаах',
    barrierColor: Colors.transparent,
    transitionDuration:
        reduce ? Duration.zero : const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => ImagePeek(images: images, initial: initial),
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
  const ImagePeek({super.key, required this.images, this.initial = 0});

  final List<String> images;
  final int initial;

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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context, rootNavigator: true).maybePop();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final reduce = reducedMotion(context);
    final cardW = math.min(900.0, mq.size.width - 32);
    final maxH = math.min(mq.size.height * 0.85,
        mq.size.height - mq.padding.top - mq.padding.bottom - 32);
    final cardH = math.max(200.0, math.min(maxH, cardW * 1.15));
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
                width: cardW,
                height: cardH,
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
                        physics: _zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _ZoomPage(
                          url: widget.images[i],
                          onZoomChanged: (z) {
                            if (z != _zoomed) setState(() => _zoomed = z);
                          },
                        ),
                      ),
                    ),
                    if (widget.images.length > 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < widget.images.length; i++)
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: i == _index
                                      ? AppColors.accent
                                      : AppColors.borderHi,
                                ),
                              ),
                          ],
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
                                child: Icon(LucideIcons.x,
                                    size: 18, color: AppColors.ink),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Нэг зураг: pinch-zoom (InteractiveViewer). Томруулсан үед дээд түвшний
/// шудрах/доош чирэх үйлдлийг зөвшөөрөхгүй байхаар `onZoomChanged` мэдэгдэнэ.
class _ZoomPage extends StatefulWidget {
  const _ZoomPage({required this.url, required this.onZoomChanged});

  final String url;
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
      child: Image.network(
        widget.url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(LucideIcons.image, size: 48, color: AppColors.muted),
        ),
      ),
    );
  }
}
