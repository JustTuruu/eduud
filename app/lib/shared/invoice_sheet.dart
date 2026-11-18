import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api/api_client.dart';
import '../core/app_config_provider.dart';
import '../core/models.dart';
import '../core/theme/app_theme.dart';
import 'top_toast.dart';
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
  bool _cooldown = false;
  Timer? _cooldownTimer;

  /// "Шалгах" товчийн доор байрлах inline төлөв (мэдэгдэл биш).
  String? _checkMessage;
  bool _checkIsError = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

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
        setState(() {
          _checkIsError = true;
          _checkMessage = apiErrorMessage(e);
        });
      }
    }
  }

  Future<void> _check() async {
    if (_checking || _cooldown) return;
    setState(() {
      _checking = true;
      _cooldown = true;
    });
    // Давтан дарж "спам" хийхээс сэргийлж ~3с хүлээлгэнэ.
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _cooldown = false);
    });
    try {
      final res = await ref.read(dioProvider).post(widget.checkPath);
      final status = (res.data as Map<String, dynamic>)['status'];
      if (!mounted) return;
      if (status == 'paid') {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _checkIsError = false;
        _checkMessage =
            'Төлбөр хараахан ороогүй байна. Банкны апп дээр төлсний дараа дахин шалгана уу.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkIsError = true;
          _checkMessage = apiErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Widget _qr(BuildContext context, TopupInvoice inv) {
    const size = 208.0;
    // QR уншигдахын тулд цагаан суурь заавал хэрэгтэй.
    return Center(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          // Dark дээр цагаан карт ялгарахын тулд нимгэн хүрээ.
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Image.network(
          inv.qrImageUrl!,
          width: size,
          height: size,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2.4),
                  ),
                ),
          errorBuilder: (_, __, ___) => SizedBox(
            width: size,
            height: size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.imageOff,
                    size: 30, color: Color(0xFF8E8E93)),
                const SizedBox(height: 10),
                Text('QR харагдсангүй. Дахин нээнэ үү.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: const Color(0xFF3C3C43))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String text) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.fill,
              ),
              child: Text('$n',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 15, height: 1.4, color: AppColors.inkSoft)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    final testMode =
        ref.watch(serverConfigProvider).valueOrNull?.paymentTestMode ?? false;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Төлбөр төлөх',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(formatMnt(inv.amountMnt),
              textAlign: TextAlign.center, style: AppTheme.price(size: 40)),
          const SizedBox(height: 4),
          Text('Төлөх дүн',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 20),
          if (inv.qrImageUrl != null)
            _qr(context, inv)
          else if (inv.qrText != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: SelectableText(inv.qrText!,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.inkSoft, height: 1.6)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inv.qrText!));
                  showTopToast(context, 'Хууллаа', kind: TopToastKind.success);
                },
                icon:
                    Icon(LucideIcons.copy, size: 15, color: AppColors.inkSoft),
                label:
                    Text('Хуулах', style: TextStyle(color: AppColors.inkSoft)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _step(1, 'Банкныхаа апп-ыг нээнэ.'),
          _step(2, 'QR кодыг уншуулж, төлбөрөө баталгаажуулна.'),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _checking ? 'Шалгаж байна…' : 'Төлсөн, шалгах',
            loading: _checking,
            onPressed: (_checking || _cooldown) ? null : _check,
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: Semantics(
              liveRegion: true,
              child: Text(
                _checkMessage ?? 'Төлбөр орж ирэхэд автоматаар баталгаажна.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: _checkIsError ? AppColors.danger : AppColors.muted,
                ),
              ),
            ),
          ),
          // Тест орчинд банк руу орох боломжгүй тул төлбөрийг симуляци хийнэ.
          if (testMode) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.warnBg,
                borderRadius: BorderRadius.circular(AppRadius.control),
                border:
                    Border.all(color: AppColors.warn.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.flaskConical,
                      size: 18, color: AppColors.warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Туршилтын горим. Банк руу орохгүйгээр төлсөн болгоно.',
                      style: TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.inkSoft),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedPressable(
                    onPressed: _simulating ? null : _simulatePayment,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(
                            color: AppColors.warn.withValues(alpha: 0.6)),
                      ),
                      child: _simulating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.warn))
                          : Text('Төлсөн болгох',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warn)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// iOS маягийн bottom sheet — бариул, дугуй дээд булан, энгийн гадаргуу.
/// (Нэр нь хуучнаар үлдсэн; blur/шилэн эффектгүй.)
Future<T?> showGlassSheet<T>(BuildContext context,
    {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.of(context).size.height * 0.92,
    ),
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.borderHi,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(child: builder(context)),
        ],
      ),
    ),
  );
}

/// Төлбөрийн sheet-ийг шилэн хэлбэрээр нээнэ. Төлөгдвөл `true` буцаана.
Future<bool?> showInvoiceSheet(
  BuildContext context, {
  required TopupInvoice invoice,
  required String checkPath,
}) =>
    showGlassSheet<bool>(
      context,
      builder: (_) =>
          PaymentInvoiceSheet(invoice: invoice, checkPath: checkPath),
    );
