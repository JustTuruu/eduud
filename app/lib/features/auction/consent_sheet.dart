import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/storage/token_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets.dart';
import '../auth/auth_controller.dart';

/// Ялагчийн төлбөр төлөх хугацаа (цаг) — backend-ийн ORDER_PAY_DEADLINE_HOURS.
const payDeadlineHours = 24;

String _key(String userId, String auctionId) => 'agreed.$userId.$auctionId';

/// Тухайн дуудлага худалдаанд өмнө нь зөвшөөрсөн эсэх.
Future<bool> hasAuctionConsent(String userId, String auctionId) async {
  try {
    return await storageRead(_key(userId, auctionId)) == '1';
  } catch (_) {
    return false;
  }
}

Future<void> rememberAuctionConsent(String userId, String auctionId) async {
  try {
    await storageWrite(_key(userId, auctionId), '1');
  } catch (_) {}
}

/// Дуудлага бүрийн анхны оролцооны өмнө дүрмийг харуулж зөвшөөрөл авна.
/// Өмнө зөвшөөрсөн бол шууд true. Болих/хаавал false.
Future<bool> ensureAuctionConsent(
  BuildContext context,
  WidgetRef ref, {
  required String auctionId,
  int? increment,
}) async {
  final userId = ref.read(authProvider).valueOrNull?.id;
  if (userId == null) return true; // нэвтрээгүй бол өөр урсгал барина
  if (await hasAuctionConsent(userId, auctionId)) return true;
  if (!context.mounted) return false;
  final ok = await showAppSheet<bool>(
    context,
    builder: (_) => ConsentSheet(increment: increment),
  );
  if (ok != true) return false;
  await rememberAuctionConsent(userId, auctionId);
  return true;
}

/// "Оролцохын өмнө" дүрмийн sheet. Зөвшөөрөл тэмдэглэтэл "Оролцох" идэвхгүй.
class ConsentSheet extends StatefulWidget {
  const ConsentSheet({super.key, this.increment});

  final int? increment;

  @override
  State<ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<ConsentSheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final inc = widget.increment;
    final priceRule = inc == null
        ? 'Оролцох бүрт үнэ өснө, хугацаа сунгагдаж болно.'
        : 'Оролцох бүрт үнэ ${formatMnt(inc)}-өөр өснө, хугацаа сунгагдаж болно.';
    final rules = <(IconData, String)>[
      (LucideIcons.ticket, 'Оролцох бүрт 1 эрх зарцуулагдана. Буцаагдахгүй.'),
      (LucideIcons.trendingUp, priceRule),
      (LucideIcons.clock, 'Хугацаа дуусахад хамгийн сүүлд оролцсон хүн ялна.'),
      (
        LucideIcons.wallet,
        'Ялвал $payDeadlineHours цагийн дотор эцсийн үнийг төлнө, '
            'эс бөгөөс захиалга цуцлагдана.'
      ),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Оролцохын өмнө',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 16),
            for (final r in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(r.$1, size: 20, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.$2,
                          style: TextStyle(
                              fontSize: 16, height: 1.35, color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            // Зөвшөөрлийн мөр
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _agreed = !_agreed),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      activeColor: AppColors.accent,
                      checkColor: AppColors.ctaInk,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                    ),
                    Expanded(
                      child: Text('Дүрмийг уншиж, зөвшөөрч байна',
                          style: TextStyle(fontSize: 16, color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/content/terms'),
                child: Text('Үйлчилгээний нөхцөл',
                    style: TextStyle(fontSize: 15, color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: 'Оролцох',
              onPressed: _agreed ? () => Navigator.of(context).pop(true) : null,
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Болих',
                    style: TextStyle(fontSize: 17, color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
