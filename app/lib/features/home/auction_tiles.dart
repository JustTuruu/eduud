import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import 'auction_timing.dart';

/// Зураггүй / ачаалж буй үеийн энгийн саарал placeholder.
class ArtPlaceholder extends StatelessWidget {
  const ArtPlaceholder({super.key, required this.seed, this.iconSize = 40});

  final String seed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.fill,
      child: Center(
        child:
            Icon(LucideIcons.package, size: iconSize, color: AppColors.muted),
      ),
    );
  }
}

/// Зураг (default дөрвөлжин): ачаалж байхад / алдаатай үед placeholder,
/// ачаалагдахад зөөлөн гарч ирнэ.
class AuctionArt extends StatelessWidget {
  const AuctionArt(
      {super.key,
      required this.auctionId,
      this.url,
      this.radius = 16,
      this.aspect = 1});

  final String auctionId;
  final String? url;
  final double radius;

  /// width / height (default дөрвөлжин).
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final placeholder = ArtPlaceholder(seed: auctionId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: aspect,
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

/// Зураг дээрх жижиг шилэн "Шагналтай" шошго (нэмэлт шагналтай дуудлагад).
class PrizeChip extends StatelessWidget {
  const PrizeChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          color: Colors.black.withValues(alpha: 0.42),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(LucideIcons.trophy, size: 13, color: Colors.white),
            SizedBox(width: 5),
            Text('Шагналтай',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}

/// Хэвтээ мөр болон бүх жагсаалтын карт: дөрвөлжин зураг + нэр + дэд мэдээлэл.
/// Удахгүй эхлэх → эхлэх цаг; дууссан → ялагч + эцсийн үнэ.
/// Зураг гадна талын өргөнийг дүүргэнэ; текст нь ~64px (зураг доор) шаардана.
class AuctionTile extends StatelessWidget {
  const AuctionTile({super.key, required this.auction, required this.onTap});

  final AuctionSummary auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final ended = a.status == 'ended' || a.status == 'settled';
    final live = a.status == 'live';
    // Дууссан/явагдаж буй: үнэ тод + дэд мөр. Удахгүй эхлэх: зөвхөн эхлэх цаг.
    String? price;
    String foot;
    var footColor = AppColors.muted;
    if (ended) {
      if (a.lastBidder != null) {
        price = formatMnt(a.currentPrice);
        foot = 'Ялагч: ${a.lastBidder!.name}';
      } else {
        foot = 'Санал ирээгүй';
      }
    } else if (live) {
      price = formatMnt(a.currentPrice);
      foot = 'Явагдаж буй';
      footColor = AppColors.accent;
    } else {
      foot = formatStartLabel(a.startsAt, DateTime.now());
    }
    const tab = [FontFeature.tabularFigures()];
    return AnimatedPressable(
      onPressed: onTap,
      scale: 0.97,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            AuctionArt(
              auctionId: a.id,
              url: a.images.isEmpty ? null : a.images.first,
              radius: 16,
            ),
            if (a.prizes.isNotEmpty)
              const Positioned(top: 8, left: 8, child: PrizeChip()),
          ]),
          const SizedBox(height: 8),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          if (price != null) ...[
            const SizedBox(height: 2),
            Text(
              price,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: tab,
                color: AppColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              color: footColor,
              fontFeatures: tab,
            ),
          ),
        ],
      ),
    );
  }
}
