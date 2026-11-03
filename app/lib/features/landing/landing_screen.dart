import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../home/home_screen.dart';

/// Landing page — нэвтрээгүй хэрэглэгчийн анхны дэлгэц (web дээр `/`).
///
/// Зөвхөн танилцуулга биш: идэвхтэй дуудлага худалдаануудыг шууд энд
/// үзүүлж, карт дээр дарвал дэлгэрэнгүй рүү (нээлттэй) орно. Санал өгөх
/// гэхэд л нэвтрэх шаардана, нэвтэрсний дараа тэр auction руугаа буцна.
/// Утас, web хоёулаа ижил дэлгэц — зөвхөн зай хуваарилалт responsive.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = Breakpoints.isWide(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageFrame(
                  maxWidth: 1120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(wide: wide),
                      _Hero(wide: wide, text: text),
                      const SizedBox(height: 44),
                      const _LiveSection(),
                      const SizedBox(height: 48),
                      _HowItWorks(wide: wide),
                      const SizedBox(height: 48),
                      _FinalCta(wide: wide),
                      const SizedBox(height: 36),
                      const _Footer(),
                      const SizedBox(height: 24),
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 24 : 20, 14, wide ? 24 : 20, 0),
      child: Row(
        children: [
          const Expanded(child: Wordmark(size: 20)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: () => context.push('/auth/login'),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Text('Нэвтрэх',
                  style: TextStyle(
                      color: AppColors.inkSoft, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 4),
            AnimatedPressable(
              onPressed: () => context.push('/auth/register'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.ctaGradient,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.sapphire.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: const Text('Бүртгүүлэх',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide, required this.text});

  final bool wide;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final title = Text(
      'Нэг цохилт л\nялалтаас тусгаарлана.',
      textAlign: wide ? TextAlign.left : TextAlign.center,
      style: text.displayLarge?.copyWith(
        fontSize: wide ? 54 : 34,
        height: 1.08,
      ),
    );
    final subtitle = Text(
      'Санал бүр 1 token. Үнэ бага багаар өснө, хугацаа сунгагдана. '
      'Хамгийн сүүлд санал өгсөн хүн барааг эцсийн үнээр авна — '
      'дэлгүүрийн үнээс хэд дахин хямд.',
      textAlign: wide ? TextAlign.left : TextAlign.center,
      style: text.bodyMedium?.copyWith(
        color: AppColors.inkSoft,
        height: 1.7,
        fontSize: wide ? 17 : 15,
      ),
    );
    final ctas = Wrap(
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: wide ? 260 : double.infinity,
          child: PrimaryButton(
            label: 'Бүртгүүлж эхлэх',
            sublabel: 'Үнэгүй, 1 минут',
            icon: LucideIcons.sparkles,
            onPressed: () => context.push('/auth/register'),
          ),
        ),
        SizedBox(
          width: wide ? 260 : double.infinity,
          child: _GhostButton(
            label: 'Идэвхтэй дуудлага үзэх',
            icon: LucideIcons.gavel,
            onPressed: () => Scrollable.ensureVisible(
              _LiveSection.anchor.currentContext ?? context,
              duration: AppMotion.slow,
              curve: AppMotion.fluid,
            ),
          ),
        ),
      ],
    );

    final copy = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const _Eyebrow(),
        const SizedBox(height: 18),
        title,
        const SizedBox(height: 18),
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: subtitle),
        const SizedBox(height: 30),
        ctas,
      ],
    );

    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
        child: copy,
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 6, child: copy),
          const SizedBox(width: 40),
          const Expanded(flex: 5, child: _HeroVisual()),
        ],
      ),
    );
  }
}

/// Хөдөлгөөнт countdown бүхий жишээ карт — penny auction-ы "амьд" мэдрэмж.
class _HeroVisual extends StatelessWidget {
  const _HeroVisual();

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glow: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              LiveBadge(),
              Spacer(),
              Icon(LucideIcons.users, size: 15, color: AppColors.muted),
              SizedBox(width: 6),
              Flexible(
                child: Text('128 оролцогч',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ),
            ]),
            const SizedBox(height: 22),
            const SectionLabel('Одоогийн үнэ'),
            const SizedBox(height: 6),
            const PriceText(amount: 12350, fontSize: 40),
            const SizedBox(height: 6),
            Text('Дэлгүүрийн үнэ 2,499,000₮',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(LucideIcons.timer,
                    size: 18, color: AppColors.sapphireSoft),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text('Дуусахад',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
                const Spacer(),
                _LoopingCountdown(
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 22),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            const PrimaryButton(
              label: 'Санал өгөх',
              sublabel: '1 token · үнэ +50₮',
              icon: LucideIcons.gavel,
            ),
          ],
        ),
      ),
    );
  }
}

/// 15 секундээс тоолоод 0 дээр дахин эхэлнэ — soft-close мэдрэмж.
class _LoopingCountdown extends StatefulWidget {
  const _LoopingCountdown({this.style});

  final TextStyle? style;

  @override
  State<_LoopingCountdown> createState() => _LoopingCountdownState();
}

class _LoopingCountdownState extends State<_LoopingCountdown> {
  late DateTime _endsAt = DateTime.now().add(const Duration(seconds: 15));

  @override
  Widget build(BuildContext context) {
    return CountdownText(
      key: ValueKey(_endsAt),
      endsAt: _endsAt,
      style: widget.style ?? const TextStyle(),
      onFinished: () {
        if (!mounted) return;
        setState(() =>
            _endsAt = DateTime.now().add(const Duration(seconds: 15)));
      },
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    return GlassChip(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(LucideIcons.zap, size: 12, color: AppColors.sapphireSoft),
        const SizedBox(width: 7),
        Flexible(
          child: Text('БАГА ҮНИЙН ДУУДЛАГА ХУДАЛДАА',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.sapphireSoft,
                    letterSpacing: 1.8,
                  )),
        ),
      ]),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onPressed: onPressed,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.sapphireSoft),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Идэвхтэй auction-ууд — нүүр дэлгэцтэй яг ижил [AuctionCard] ашиглана.
class _LiveSection extends ConsumerWidget {
  const _LiveSection();

  static final anchor = GlobalKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(auctionListProvider('live'));
    final wide = Breakpoints.isWide(context);
    final pad = wide ? 24.0 : 16.0;

    return Column(
      key: anchor,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad + 4),
          child: Row(children: [
            const LiveBadge(),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Яг одоо явагдаж байна',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: 22)),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        live.when(
          loading: () => Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: const SkeletonCard(),
          ),
          error: (e, _) => EmptyState(
            icon: LucideIcons.wifiOff,
            title: apiErrorMessage(e),
            subtitle: 'Хуудсыг дахин ачаална уу.',
          ),
          data: (auctions) => auctions.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.gavel,
                  title: 'Идэвхтэй дуудлага худалдаа алга',
                  subtitle: 'Шинэ дуудлага худалдаа эхлэхэд энд гарч ирнэ.',
                )
              : AuctionGrid(
                  auctions: auctions.take(6).toList(),
                  padding: EdgeInsets.symmetric(horizontal: pad),
                ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});

  final bool wide;

  static const _steps = [
    (
      LucideIcons.gem,
      'Token ав',
      'Дансаа цэнэглээд token авна. Нэг санал = 1 token.',
    ),
    (
      LucideIcons.gavel,
      'Санал өг',
      'Санал бүрт үнэ бага зэрэг өсч, дуусах хугацаа сунгагдана. '
          'Сүүлийн секундүүд хамгийн халуун.',
    ),
    (
      LucideIcons.trophy,
      'Ял, төл, ав',
      'Хугацаа дуусахад хамгийн сүүлд санал өгсөн хүн ялна. '
          'Эцсийн үнийг төлөөд барааг авна.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cards = List.generate(_steps.length, (i) {
      final (icon, title, body) = _steps[i];
      return GlowCard(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.balGradient,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderHi),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.sapphireSoft),
                ),
                const SizedBox(width: 14),
                Text(
                  '0${i + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        letterSpacing: 2,
                      ),
                ),
              ]),
              const SizedBox(height: 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(body,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.65)),
            ],
          ),
        ),
      );
    });

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Хэрхэн ажилладаг вэ?',
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(fontSize: 22)),
          ),
          const SizedBox(height: 16),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: cards[i]),
                ],
              ],
            )
          else
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              cards[i],
            ],
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  const _FinalCta({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
      child: GlowCard(
        glow: true,
        child: Container(
          padding: EdgeInsets.all(wide ? 40 : 26),
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.6,
              colors: [Color(0xFF16294F), Color(0xFF0B1220)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Дараагийн ялагч та байж болно.',
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(fontSize: wide ? 30 : 24)),
              const SizedBox(height: 10),
              Text('Бүртгүүлээд, token аваад, санал өгөөд л болоо.',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),
              SizedBox(
                width: wide ? 280 : double.infinity,
                child: PrimaryButton(
                  label: 'Бүртгүүлэх',
                  icon: LucideIcons.badgeCheck,
                  onPressed: () => context.push('/auth/register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final link = TextStyle(
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.border,
    );
    Widget l(String label, String path) => TextButton(
          onPressed: () => context.push(path),
          child: Text(label, style: link),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Text('© E-Duud',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
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
