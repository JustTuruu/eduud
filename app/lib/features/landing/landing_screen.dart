import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ambient_backdrop.dart';
import '../../shared/app_nav_bar.dart' show Wordmark;
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../home/auction_tiles.dart';
import '../home/auction_timing.dart';
import '../home/home_screen.dart' show auctionListProvider;

/// Landing — нэвтрээгүй хэрэглэгчийн анхны дэлгэц (web дээр `/`).
///
/// "Одоо тоглож буй" ертөнцөөрөө шууд зарна: яг одоо явагдаж буй дуудлагыг
/// том зурагтай нь харуулж, түүний өнгө дэлгэц даяар тархана. Доор нь
/// ажиллах зарчим, удахгүй эхлэх мөр, төгсгөлийн урилга.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  /// Нэг удаагийн орж ирэлт: гарчиг → одоо явагдаж буй бараа.
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _copyIn = CurvedAnimation(
      parent: _enter, curve: const Interval(0, 0.6, curve: AppMotion.fluid));
  late final Animation<double> _nowIn = CurvedAnimation(
      parent: _enter, curve: const Interval(0.25, 1, curve: AppMotion.fluid));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reducedMotion(context)) {
        _enter.value = 1;
      } else {
        unawaited(_enter.forward());
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final live = ref.watch(auctionListProvider('live'));
    final upcoming = ref.watch(auctionListProvider('scheduled'));

    final liveList = [...(live.valueOrNull ?? const <AuctionSummary>[])]
      ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    final upcomingList = [...(upcoming.valueOrNull ?? const <AuctionSummary>[])]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final featured = liveList.isNotEmpty
        ? liveList.first
        : (upcomingList.isNotEmpty ? upcomingList.first : null);
    final imageUrl = (featured != null && featured.images.isNotEmpty)
        ? featured.images.first
        : null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AmbientBackdrop(
              image: imageUrl == null ? null : NetworkImage(imageUrl),
              imageKey: imageUrl,
              seed: featured?.id ?? 'e-duud',
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: PageFrame(
                    maxWidth: 1200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(wide: wide),
                        _Hero(
                          wide: wide,
                          copyIn: _copyIn,
                          nowIn: _nowIn,
                          live: live,
                          featured: featured,
                          isLive: liveList.isNotEmpty,
                          onRetry: () =>
                              ref.invalidate(auctionListProvider('live')),
                        ),
                        if (liveList.length > 1) ...[
                          SizedBox(height: wide ? 72 : 48),
                          _Shelf(
                            title: 'Яг одоо явагдаж буй',
                            auctions: liveList.skip(1).toList(),
                          ),
                        ],
                        SizedBox(height: wide ? 96 : 64),
                        _HowItWorks(wide: wide),
                        if (upcomingList.isNotEmpty) ...[
                          SizedBox(height: wide ? 96 : 64),
                          _Shelf(
                            title: 'Удахгүй эхлэх',
                            auctions: upcomingList.take(10).toList(),
                          ),
                        ],
                        SizedBox(height: wide ? 96 : 64),
                        _FinalCta(wide: wide),
                        const SizedBox(height: 48),
                        const _Footer(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Дээд мөр
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final pad = wide ? 32.0 : 20.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
      child: Row(
        children: [
          const Expanded(
              child: Align(
            alignment: Alignment.centerLeft,
            child: Wordmark(size: 21),
          )),
          TextButton(
            onPressed: () => context.push('/auth/login'),
            style: TextButton.styleFrom(
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: const Text('Нэвтрэх',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          AnimatedPressable(
            onPressed: () => context.push('/auth/register'),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.borderHi),
                color: AppColors.surface.withValues(alpha: 0.6),
              ),
              child: const Text('Бүртгүүлэх',
                  style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child, this.dy = 20});

  final Animation<double> animation;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
              offset: Offset(0, dy * (1 - t)), child: child),
        );
      },
      child: child,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.wide,
    required this.copyIn,
    required this.nowIn,
    required this.live,
    required this.featured,
    required this.isLive,
    required this.onRetry,
  });

  final bool wide;
  final Animation<double> copyIn;
  final Animation<double> nowIn;
  final AsyncValue<List<AuctionSummary>> live;
  final AuctionSummary? featured;
  final bool isLive;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final copy = _Reveal(animation: copyIn, child: _HeroCopy(wide: wide));

    Widget now;
    if (live.isLoading && featured == null) {
      now = _NowSkeleton(wide: wide);
    } else if (live.hasError && featured == null) {
      now = _NowError(onRetry: onRetry);
    } else if (featured == null) {
      now = const _NowEmpty();
    } else {
      now = _NowPlaying(auction: featured!, isLive: isLive, wide: wide);
    }
    now = _Reveal(animation: nowIn, dy: 28, child: now);

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [copy, const SizedBox(height: 48), now],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: copy),
          const SizedBox(width: 64),
          Expanded(flex: 9, child: Center(child: now)),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Нэг санал — нэг эрх.',
          style: text.displayLarge?.copyWith(
            fontSize: wide ? 64 : 38,
            height: 1.05,
            letterSpacing: wide ? -1.2 : -0.6,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            'Хамгийн сүүлд санал өгсөн хүн бараагаа авна. '
            'Үнэ бага багаар өсдөг тул барааг ихэвчлэн хямд авдаг.',
            style: TextStyle(
              fontSize: wide ? 18 : 16,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: wide ? 240 : double.infinity,
              child: PrimaryButton(
                label: 'Бүртгүүлэх',
                icon: LucideIcons.userPlus,
                onPressed: () => context.push('/auth/register'),
              ),
            ),
            SizedBox(
              width: wide ? 160 : double.infinity,
              child: _OutlineButton(
                label: 'Нэвтрэх',
                onPressed: () => context.push('/auth/login'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AnimatedPressable(
        onPressed: onPressed,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.borderHi),
            color: AppColors.surface.withValues(alpha: 0.5),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Одоо явагдаж буй (hero artwork)
// ---------------------------------------------------------------------------

class _NowPlaying extends StatefulWidget {
  const _NowPlaying(
      {required this.auction, required this.isLive, required this.wide});

  final AuctionSummary auction;
  final bool isLive;
  final bool wide;

  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.auction;
    final live = widget.isLive;
    final left = a.endsAt.difference(_now);
    final urgent = live && left.inSeconds <= 10 && left > Duration.zero;
    final fraction = live
        ? remainingFraction(startsAt: a.startsAt, endsAt: a.endsAt, now: _now)
        : 1.0;
    final maxW = widget.wide ? 440.0 : 360.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Semantics(
        button: true,
        label: a.title,
        child: AnimatedPressable(
          scale: 0.985,
          onPressed: () => context.push('/auctions/${a.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: live ? AppColors.live : AppColors.coralLight,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  live ? 'Одоо явагдаж буй' : 'Удахгүй эхлэх',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
              ]),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.art),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 22),
                    ),
                  ],
                ),
                child: AuctionArt(
                  auctionId: a.id,
                  url: a.images.isEmpty ? null : a.images.first,
                  radius: AppRadius.art,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                a.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                live
                    ? (a.lastBidder != null
                        ? 'Тэргүүлж байна: ${a.lastBidder!.name}'
                        : 'Санал өгөх хүн хүлээж байна')
                    : 'Эхлэх: ${formatStartLabel(a.startsAt, _now)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              Text(
                formatMnt(a.currentPrice),
                style: AppTheme.price(size: 44, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              _TimerBar(fraction: fraction, urgent: urgent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    live ? formatRemaining(left) : 'Эхлээгүй',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: urgent ? AppColors.coral : AppColors.inkSoft,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${a.bidCount} санал',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                      fontFeatures: [FontFeature.tabularFigures()],
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
}

/// Үлдсэн хугацааны зурвас: урт нь яг үлдсэн хувь, сүүлийн 10с лугшина.
class _TimerBar extends StatelessWidget {
  const _TimerBar({required this.fraction, required this.urgent});

  final double fraction;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth * fraction;
      return SizedBox(
        height: 6,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.ink.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 900),
              curve: Curves.linear,
              width: w,
              height: 6,
              decoration: BoxDecoration(
                color: urgent ? AppColors.coralLight : AppColors.coral,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _NowSkeleton extends StatelessWidget {
  const _NowSkeleton({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 440 : 360),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 18, width: 140),
          SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1,
            child: Skeleton(height: double.infinity, radius: AppRadius.art),
          ),
          SizedBox(height: 20),
          Skeleton(height: 22, width: 220),
          SizedBox(height: 12),
          Skeleton(height: 40, width: 180),
        ],
      ),
    );
  }
}

class _NowEmpty extends StatelessWidget {
  const _NowEmpty();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.art),
            child: const AspectRatio(
              aspectRatio: 1,
              child: ArtPlaceholder(seed: 'e-duud', iconSize: 56),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Одоогоор явагдаж буй дуудлага алга',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text('Шинэ дуудлага эхлэхэд энд гарч ирнэ.',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _NowError extends StatelessWidget {
  const _NowError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.surfaceHi),
            child: const Icon(LucideIcons.wifiOff,
                size: 24, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const Text('Холболт тасарлаа. Дахин оролдоно уу.',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: _OutlineButton(label: 'Дахин оролдох', onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Хэвтээ мөр (цомгийн тавиур)
// ---------------------------------------------------------------------------

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.auctions});

  final String title;
  final List<AuctionSummary> auctions;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    final pad = wide ? 32.0 : 20.0;
    final tileW = wide ? 184.0 : 148.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Text(title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: tileW + 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: pad),
            itemCount: auctions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) => SizedBox(
              width: tileW,
              child: AuctionTile(
                auction: auctions[i],
                onTap: () => context.push('/auctions/${auctions[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Хэрхэн ажилладаг вэ
// ---------------------------------------------------------------------------

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final pad = wide ? 32.0 : 20.0;
    final steps = [
      const _Step(
        number: '1',
        title: 'Эрх ав',
        body: 'Эрх цэнэглээд аваарай. Нэг санал өгөхөд 1 эрх зарцуулагдана.',
        visual: _EarnVisual(),
      ),
      const _Step(
        number: '2',
        title: 'Санал өг',
        body: 'Санал бүр үнийг бага зэрэг өсгөнө. Сүүлийн секундэд санал орвол '
            'хугацаа сунгагдана.',
        visual: _BidVisual(),
      ),
      const _Step(
        number: '3',
        title: 'Хамгийн сүүлд өгсөн нь авна',
        body: 'Хугацаа дуусахад хамгийн сүүлд санал өгсөн хүн эцсийн үнийг '
            'төлөөд бараагаа авна.',
        visual: _WinVisual(),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Хэрхэн ажилладаг вэ?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: wide ? 32 : 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          SizedBox(height: wide ? 32 : 24),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 40),
                  Expanded(flex: i == 1 ? 6 : 5, child: steps[i]),
                ],
              ],
            )
          else
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const SizedBox(height: 40),
              steps[i],
            ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.body,
    required this.visual,
  });

  final String number;
  final String title;
  final String body;
  final Widget visual;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 148,
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.border),
          ),
          child: visual,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              number,
              style: AppTheme.price(size: 40, color: AppColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(body,
            style: const TextStyle(
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft)),
      ],
    );
  }
}

/// 1 эрх = 1 санал.
class _EarnVisual extends StatelessWidget {
  const _EarnVisual();

  @override
  Widget build(BuildContext context) {
    Widget chip(String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHi.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.gem, size: 16, color: AppColors.coral),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        );
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chip('1 эрх'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(LucideIcons.arrowRight,
                size: 20, color: AppColors.inkSoft),
          ),
          const Flexible(
            child: Text('1 санал',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// Үнэ өсөж, хугацаа сунгагдах жишээ.
class _BidVisual extends StatelessWidget {
  const _BidVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatMnt(12400),
                style: AppTheme.price(size: 34, color: AppColors.ink)),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('+50₮',
                  style: AppTheme.price(size: 16, color: AppColors.success)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _TimerBar(fraction: 0.18, urgent: false),
        const SizedBox(height: 8),
        const Text('Хугацаа 10 секундээр сунгагдлаа',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
      ],
    );
  }
}

/// Ялалтын жишээ — алт зөвхөн ялалтад.
class _WinVisual extends StatelessWidget {
  const _WinVisual();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(LucideIcons.trophy, size: 20, color: AppColors.gold),
          const SizedBox(width: 8),
          const Text('Та яллаа!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
        ]),
        const SizedBox(height: 10),
        Text(formatMnt(12450),
            style: AppTheme.price(size: 34, color: AppColors.gold)),
        const SizedBox(height: 6),
        const Text('Эцсийн үнээ төлөөд бараагаа аваарай',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.inkSoft)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Төгсгөл
// ---------------------------------------------------------------------------

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20),
      child: Column(
        crossAxisAlignment:
            wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            'Дараагийн ялагч та байж болно.',
            textAlign: wide ? TextAlign.center : TextAlign.left,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontSize: wide ? 40 : 30, height: 1.15, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Text(
            'Бүртгүүлээд, эрх аваад, санал өгч эхлээрэй.',
            textAlign: wide ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: wide ? 280 : double.infinity,
            child: PrimaryButton(
              label: 'Бүртгүүлэх',
              icon: LucideIcons.userPlus,
              onPressed: () => context.push('/auth/register'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.inkSoft,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    Widget l(String label, String path) => TextButton(
          onPressed: () => context.push(path),
          style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
          child: Text(label, style: link),
        );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('© E-Duud', style: link),
          ),
          l('Үйлчилгээний нөхцөл', '/content/terms'),
          l('Нууцлал', '/content/privacy'),
          l('Түгээмэл асуулт', '/content/faq'),
          l('Тусламж', '/help'),
        ],
      ),
    );
  }
}
