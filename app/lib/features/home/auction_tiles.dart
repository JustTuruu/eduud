import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/ambient_backdrop.dart';
import '../../shared/widgets.dart';
import 'auction_timing.dart';

/// Зураггүй / ачаалж буй үеийн "цомгийн хавтас" — auction id-аас тогтсон
/// өнгөтэй, ертөнцөөсөө гарахгүй placeholder.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({super.key, required this.seed, this.iconSize = 40});

  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = AmbientPalette.fromSeed(seed);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.surfaceHi, c[0], 0.55)!,
            Color.lerp(AppColors.surface, c[1], 0.4)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(LucideIcons.gavel,
            size: iconSize, color: AppColors.ink.withValues(alpha: 0.22)),
      ),
    );
  }
}

/// Дөрвөлжин "цомог" зураг: ачаалж байхад / алдаатай үед placeholder,
/// ачаалагдахад зөөлөн гарч ирнэ.
class AuctionArt extends StatelessWidget {
  const AuctionArt(
      {super.key, required this.auctionId, this.url, this.radius = 20});

  final String auctionId;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = ArtPlaceholder(seed: auctionId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 1,
        child: url == null || url!.isEmpty
            ? placeholder
            : Image.network(
                url!,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, sync) {
                  if (sync) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: AppMotion.base,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

/// Хэвтээ мөр болон бүх жагсаалтын карт: дөрвөлжин зураг + нэр + дэд мэдээлэл.
/// Удахгүй эхлэх → эхлэх цаг; дууссан → ялагч + эцсийн үнэ.
class AuctionTile extends StatelessWidget {
  const AuctionTile({super.key, required this.auction, required this.onTap});

  final AuctionSummary auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final text = Theme.of(context).textTheme;
    final ended = a.status == 'ended' || a.status == 'settled';
    return AnimatedPressable(
      onPressed: onTap,
      scale: 0.97,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuctionArt(
            auctionId: a.id,
            url: a.images.isEmpty ? null : a.images.first,
          ),
          const SizedBox(height: 8),
          Text(
            a.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
          const SizedBox(height: 4),
          if (ended) ...[
            Text(
              a.lastBidder != null ? a.lastBidder!.name : 'Ялагчгүй',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            if (a.lastBidder != null)
              Text(formatMnt(a.currentPrice),
                  style: AppTheme.price(size: 15, color: AppColors.gold)),
          ] else
            Row(children: [
              const Icon(LucideIcons.clock,
                  size: 13, color: AppColors.coralLight),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  formatStartLabel(a.startsAt, DateTime.now()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}
