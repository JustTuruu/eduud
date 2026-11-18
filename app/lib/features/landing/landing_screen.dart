import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../home/auction_tiles.dart';
import '../home/auction_timing.dart';
import '../home/home_screen.dart' show auctionListProvider;

/// Landing — нэвтрээгүй хэрэглэгчийн анхны дэлгэц (web дээр `/`).
///
/// Apple-ийн бүтээгдэхүүний хуудас шиг цэвэр: гарчиг, нэг мөр тайлбар,
/// хоёр товч, явагдаж буй нэг дуудлага, ажиллах зарчим, удахгүй эхлэх мөр.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = Breakpoints.isWide(context);
    final live = ref.watch(auctionListProvider('live'));
    final upcoming = ref.watch(auctionListProvider('scheduled'));

    final liveList = [...(live.valueOrNull ?? const <AuctionSummary>[])]
      ..sort((a, b) => a.endsAt.compareTo(b.endsAt));
    final upcomingList = [...(upcoming.valueOrNull ?? const <AuctionSummary>[])]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final side = wide ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageFrame(
                maxWidth: 1120,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TopBar(),
                      SizedBox(height: wide ? 72 : 40),
                      _Hero(wide: wide),
                      SizedBox(height: wide ? 64 : 40),
                      if (liveList.isNotEmpty)
                        _LiveCard(auction: liveList.first, wide: wide)
                      else if (live.isLoading)
                        const SkeletonCard(),
                      SizedBox(height: wide ? 96 : 56),
                      _HowItWorks(wide: wide),
                      if (upcomingList.isNotEmpty) ...[
                        SizedBox(height: wide ? 96 : 56),
                        _Upcoming(list: upcomingList, wide: wide),
                      ],
                      SizedBox(height: wide ? 96 : 56),
                      const _Footer(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Text('E-Duud',
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: AppColors.ink)),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(left: 3, top: 8),
            decoration:
                BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.push('/auth/login'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: const Size(44, 44)),
            child: const Text('Нэвтрэх',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final align = wide ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final ta = wide ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          'Нэг санал — нэг эрх.',
          textAlign: ta,
          style: TextStyle(
            fontSize: wide ? 56 : 36,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: wide ? -1.2 : -0.8,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Хамгийн сүүлд санал өгсөн хүн барааг эцсийн үнээр авна.',
            textAlign: ta,
            style: TextStyle(
                fontSize: wide ? 21 : 17,
                height: 1.4,
                color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.center : WrapAlignment.start,
          children: [
            SizedBox(
              width: wide ? 180 : null,
              child: PrimaryButton(
                label: 'Бүртгүүлэх',
                onPressed: () => context.push('/auth/register'),
              ),
            ),
            SizedBox(
              width: wide ? 180 : null,
              child: SecondaryButton(
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

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.auction, required this.wide});
  final AuctionSummary auction;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final now = DateTime.now();
    final fraction =
        remainingFraction(startsAt: a.startsAt, endsAt: a.endsAt, now: now);
    final leader =
        a.lastBidder != null ? 'Тэргүүлж байна: ${a.lastBidder!.name}' : null;

    final art = AuctionArt(
      auctionId: a.id,
      url: a.images.isEmpty ? null : a.images.first,
      radius: 20,
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const LiveBadge(),
        const SizedBox(height: 12),
        Text(a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: wide ? 28 : 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: AppColors.ink)),
        if (leader != null) ...[
          const SizedBox(height: 6),
          Text(leader,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: AppColors.muted)),
        ],
        const SizedBox(height: 16),
        Text(formatMnt(a.currentPrice),
            style: AppTheme.price(size: wide ? 40 : 32, color: AppColors.ink)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 4,
            backgroundColor: AppColors.fill,
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          CountdownText(
            endsAt: a.endsAt,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          Text('${a.bidCount} санал',
              style: TextStyle(fontSize: 15, color: AppColors.muted)),
        ]),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Санал өгөх',
          onPressed: () => context.push('/auctions/${a.id}'),
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(wide ? 24 : 16),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: wide
          ? Row(children: [
              SizedBox(width: 360, child: art),
              const SizedBox(width: 40),
              Expanded(child: info),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [art, const SizedBox(height: 20), info],
            ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});
  final bool wide;

  static const _steps = [
    (
      CupertinoIcons.person_crop_circle,
      'Бүртгүүлнэ',
      'Утасны дугаараараа минутанд бүртгүүлнэ.'
    ),
    (
      CupertinoIcons.hand_raised_fill,
      'Санал өгнө',
      'Санал бүр 1 эрх зарцуулж, үнийг нэмнэ.'
    ),
    (
      CupertinoIcons.gift_fill,
      'Бараагаа авна',
      'Хамгийн сүүлд санал өгсөн хүн яллаа.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      for (var i = 0; i < _steps.length; i++)
        _Step(n: i + 1, icon: _steps[i].$1, title: _steps[i].$2, body: _steps[i].$3),
    ];
    return Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text('Хэрхэн ажилладаг вэ?',
            style: TextStyle(
                fontSize: wide ? 40 : 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AppColors.ink)),
        SizedBox(height: wide ? 40 : 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 32),
                Expanded(child: items[i]),
              ],
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 20),
                items[i],
              ],
            ],
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.n,
      required this.icon,
      required this.title,
      required this.body});
  final int n;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 24, color: AppColors.accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$n. $title',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(
                      fontSize: 15, height: 1.4, color: AppColors.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.list, required this.wide});
  final List<AuctionSummary> list;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tileW = wide ? 200.0 : 150.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Удахгүй эхлэх',
            style: TextStyle(
                fontSize: wide ? 28 : 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 16),
        SizedBox(
          height: tileW + 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => SizedBox(
              width: tileW,
              child: AuctionTile(
                auction: list[i],
                onTap: () => context.push('/auctions/${list[i].id}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String path) => TextButton(
          onPressed: () => context.push(path),
          style: TextButton.styleFrom(
              foregroundColor: AppColors.muted,
              minimumSize: const Size(44, 44)),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        );
    return Column(
      children: [
        Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            link('Үйлчилгээний нөхцөл', '/content/terms'),
            link('Нууцлал', '/content/privacy'),
            link('Түгээмэл асуулт', '/content/faq'),
            link('Тусламж', '/help'),
          ],
        ),
        Text('© E-Duud',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}
