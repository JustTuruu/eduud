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
        child: Icon(LucideIcons.package,
            size: iconSize, color: AppColors.muted),
      ),
    );
  }
}

/// Дөрвөлжин зураг: ачаалж байхад / алдаатай үед placeholder,
/// ачаалагдахад зөөлөн гарч ирнэ.
class AuctionArt extends StatelessWidget {
  const AuctionArt(
      {super.key, required this.auctionId, this.url, this.radius = 16});

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
/// Зураг гадна талын өргөнийг дүүргэнэ; текст нь ~64px (зураг доор) шаардана.
class AuctionTile extends StatelessWidget {
  const AuctionTile({super.key, required this.auction, required this.onTap});

  final AuctionSummary auction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = auction;
    final ended = a.status == 'ended' || a.status == 'settled';
    final String foot;
    if (ended) {
      foot = a.lastBidder != null
          ? '${a.lastBidder!.name} · ${formatMnt(a.currentPrice)}'
          : 'Ялагчгүй';
    } else {
      foot = formatStartLabel(a.startsAt, DateTime.now());
    }
    return AnimatedPressable(
      onPressed: onTap,
      scale: 0.97,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuctionArt(
            auctionId: a.id,
            url: a.images.isEmpty ? null : a.images.first,
            radius: 14,
          ),
          const SizedBox(height: 6),
          Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            foot,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              color: AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
