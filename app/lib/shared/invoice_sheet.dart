import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api/api_client.dart';
import '../core/app_config_provider.dart';
import '../core/models.dart';
import '../core/theme/app_theme.dart';
import 'form_widgets.dart';
import 'widgets.dart';

/// wire.mn нэхэмжлэхийн QR төлбөрийн sheet — цэнэглэлт болон ялсан барааны
/// төлбөрт хоёуланд нь хэрэглэгдэнэ.
///
/// Төлбөр батлагдвал `true` утгатайгаар хаагдана; дараагийн үйлдлийг
/// (профайл сэргээх, жагсаалт шинэчлэх г.м.) дуудсан тал өөрөө хийнэ.
class PaymentInvoiceSheet extends ConsumerStatefulWidget {
  const PaymentInvoiceSheet({
    super.key,
    required this.invoice,
    required this.checkPath,
  });

  final TopupInvoice invoice;

  /// Төлбөр шалгах POST endpoint — `{status}` буцаана.
  final String checkPath;

  @override
  ConsumerState<PaymentInvoiceSheet> createState() =>
      _PaymentInvoiceSheetState();
}

class _PaymentInvoiceSheetState extends ConsumerState<PaymentInvoiceSheet> {
  bool _checking = false;
  bool _simulating = false;

  /// Зөвхөн тест орчинд: банк руу орохгүйгээр төлбөрийг батлагдсан болгоно.
  Future<void> _simulatePayment() async {
    setState(() => _simulating = true);
    try {
      await ref
          .read(dioProvider)
          .post('/payments/wire/test-pay/${widget.invoice.invoiceId}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _simulating = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final res = await ref.read(dioProvider).post(widget.checkPath);
      final status = (res.data as Map<String, dynamic>)['status'];
      if (!mounted) return;
      if (status == 'paid') {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Төлбөр хараахан хийгдээгүй байна.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 32 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Төлбөр'),
          const SizedBox(height: 8),
          Center(child: PriceText(amount: inv.amountMnt, fontSize: 32)),
          const SizedBox(height: 20),
          if (inv.qrImageUrl != null)
            Center(
              child: GlowCard(
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      inv.qrImageUrl!,
                      width: 190,
                      height: 190,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const SizedBox(
                                  width: 190,
                                  height: 190,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.sapphire,
                                        strokeWidth: 2.4),
                                  ),
                                ),
                      // QR зураг ачаалагдахгүй бол хоосон нүх биш ойлгомжтой
                      // мессеж харуулна.
                      errorBuilder: (_, __, ___) => SizedBox(
                        width: 190,
                        height: 190,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.imageOff,
                                size: 30, color: AppColors.muted),
                            const SizedBox(height: 10),
                            Text('QR ачаалагдсангүй',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (inv.qrText != null) ...[
            GlowCard(
              radius: 18,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(inv.qrText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.inkSoft, height: 1.6)),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.qrText!));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Хууллаа')));
                },
                icon: const Icon(LucideIcons.copy,
                    size: 15, color: AppColors.muted),
                label: const Text('Хуулах',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Банкны апп-аараа QR уншуулан төлнө үү. Төлбөр хийгдмэгц автоматаар баталгаажна.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Төлбөр шалгах',
            icon: LucideIcons.refreshCw,
            loading: _checking,
            onPressed: _checking ? null : _check,
          ),
          // Тест орчинд банк руу орох боломжгүй тул төлбөрийг симуляци хийнэ.
          if (ref.watch(serverConfigProvider).valueOrNull?.paymentTestMode ??
              false) ...[
            const SizedBox(height: 14),
            TestModeCard(
              title: 'Банкны төлбөр жинхэнээсээ хийгдэхгүй. Доорх товчоор '
                  'төлөгдсөн гэж үзнэ.',
              actionLabel: 'Төлөгдсөн гэж үзэх',
              loading: _simulating,
              onAction: _simulatePayment,
            ),
          ],
        ],
      ),
    );
  }
}
