import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/app_nav_bar.dart';
import '../../shared/form_widgets.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../wallet/sub_page.dart';
import 'request_validators.dart';

final myRequestsProvider =
    FutureProvider.autoDispose<List<AuctionRequest>>((ref) async {
  final res = await ref.watch(dioProvider).get('/auction-requests/mine');
  return (res.data as List)
      .map((e) => AuctionRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _categories = [
  'Электроник',
  'Гэр ахуй',
  'Хувцас',
  'Тээврийн хэрэгсэл',
  'Бусад',
];

/// Хүсэлт — өөрийн барааг дуудлага худалдаанд оруулах хүсэлт илгээх + түүх.
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _preferred = TextEditingController();
  final _other = TextEditingController();

  String? _category;
  bool _loading = false;
  int _shake = 0;
  bool _touched = false;

  String? _formError;
  String? _titleError;
  String? _descError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _description.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _preferred.dispose();
    _other.dispose();
    super.dispose();
  }

  bool _validate() {
    final t = RequestValidators.title(_title.text);
    final d = RequestValidators.description(_description.text);
    final p = RequestValidators.startPrice(_price.text);
    setState(() {
      _touched = true;
      _titleError = t;
      _descError = d;
      _priceError = p;
      _formError = null;
      if (t != null || d != null || p != null) _shake++;
    });
    return t == null && d == null && p == null;
  }

  void _revalidate() {
    if (!_touched) return;
    setState(() {
      _titleError = RequestValidators.title(_title.text);
      _descError = RequestValidators.description(_description.text);
      _priceError = RequestValidators.startPrice(_price.text);
    });
  }

  Future<void> _submit({required bool draft}) async {
    if (!_validate()) return;
    setState(() => _loading = true);
    String? opt(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    try {
      await ref.read(dioProvider).post('/auction-requests', data: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        if (_category != null) 'category': _category,
        if (opt(_price) != null) 'startPrice': int.parse(_price.text.trim()),
        if (opt(_preferred) != null) 'preferredDate': opt(_preferred),
        if (opt(_other) != null) 'otherInfo': opt(_other),
        if (draft) 'draft': true,
      });
      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _loading = false;
        _touched = false;
        _category = null;
        _titleError = _descError = _priceError = null;
        _title.clear();
        _description.clear();
        _price.clear();
        _preferred.clear();
        _other.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(draft ? 'Ноорог хадгалагдлаа.' : 'Хүсэлт илгээгдлээ.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _formError = apiErrorMessage(e);
        _shake++;
      });
    }
  }

  Future<void> _cancel(AuctionRequest r) async {
    final ok = await showAppSheet<bool>(
      context,
      builder: (ctx) => _CancelSheet(title: r.title),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/auction-requests/${r.id}/cancel');
      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Хүсэлт цуцлагдлаа.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(apiErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final history = ref.watch(myRequestsProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final wide = Breakpoints.isWide(context);
    final bottom = (wide ? 40.0 : NavMetrics.bottomInset(context)) + viewInsets;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'requests',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, bottom),
              children: [
                Reveal(
                  index: 0,
                  child: Text('Бараагаа дуудлага худалдаанд оруулах',
                      style: text.displayMedium),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Барааныхаа мэдээллийг илгээгээрэй — бид хянаж, '
                  'тохирвол дуудлага худалдаанд оруулна.',
                  style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 32),
                ErrorBanner(message: _formError, shakeToken: _shake),
                const PlainLabel('Барааны мэдээлэл'),
                const SizedBox(height: 16),
                AppField(
                  label: 'Барааны нэр *',
                  controller: _title,
                  hint: 'Жиш. iPhone 15 Pro 256GB',
                  error: _titleError,
                  maxLength: 120,
                  enabled: !_loading,
                  shakeToken: _titleError == null ? 0 : _shake,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _revalidate(),
                ),
                const SizedBox(height: 18),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: PlainLabel('Ангилал'),
                ),
                AppChoiceChips<String>(
                  options: [for (final c in _categories) ChipOption(c, c)],
                  selected: _category,
                  onSelected: (v) =>
                      setState(() => _category = v == _category ? null : v),
                ),
                const SizedBox(height: 18),
                AppField(
                  label: 'Тайлбар *',
                  controller: _description,
                  hint: 'Байдал, жил, дутагдал, багцад юу орох зэргийг бичнэ үү.',
                  error: _descError,
                  helper: _descError == null
                      ? '${_description.text.characters.length} / 4000'
                      : null,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 4000,
                  enabled: !_loading,
                  shakeToken: _descError == null ? 0 : _shake,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _revalidate(),
                ),
                const SizedBox(height: 18),
                AppField(
                  label: 'Хүссэн эхлэх үнэ (₮)',
                  controller: _price,
                  hint: '0',
                  error: _priceError,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 12,
                  enabled: !_loading,
                  shakeToken: _priceError == null ? 0 : _shake,
                  onChanged: (_) => _revalidate(),
                ),
                const SizedBox(height: 28),
                const PlainLabel('Бусад мэдээлэл'),
                const SizedBox(height: 16),
                AppField(
                  label: 'Тохиромжтой хугацаа',
                  controller: _preferred,
                  hint: 'Жиш. 12-р сарын эхний долоо хоног, орой 20:00',
                  maxLength: 120,
                  enabled: !_loading,
                ),
                const SizedBox(height: 18),
                AppField(
                  label: 'Нэмэлт мэдээлэл',
                  controller: _other,
                  hint: 'Бидэнд мэдэгдэх бусад зүйл.',
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 2000,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Илгээх',
                  icon: LucideIcons.send,
                  loading: _loading,
                  onPressed: _loading ? null : () => _submit(draft: false),
                ),
                const SizedBox(height: 12),
                _GhostButton(
                  label: 'Ноорог хадгалах',
                  onPressed: _loading ? null : () => _submit(draft: true),
                ),
                const SizedBox(height: 48),
                const Reveal(
                  index: 1,
                  child: Text('Миний хүсэлтүүд',
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.ink)),
                ),
                const SizedBox(height: 16),
                history.when(
                  loading: () => const Column(children: [
                    Skeleton(height: 88, radius: 16),
                    SizedBox(height: 12),
                    Skeleton(height: 88, radius: 16),
                  ]),
                  error: (e, _) => Column(children: [
                    Text(apiErrorMessage(e),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft)),
                    const SizedBox(height: 12),
                    _GhostButton(
                      label: 'Дахин оролдох',
                      onPressed: () => ref.invalidate(myRequestsProvider),
                    ),
                  ]),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: LucideIcons.filePlus2,
                          title: 'Хүсэлт хараахан алга',
                          subtitle: 'Илгээсэн хүсэлт энд харагдана.',
                        )
                      : Column(children: [
                          for (final r in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RequestTile(
                                item: r,
                                onCancel: () => unawaited(_cancel(r)),
                              ),
                            ),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Хоёрдогч үйлдэл — хүрээтэй, дүүргэлтгүй (ганц coral CTA-г давахгүй).
class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onPressed: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.borderHi),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: onPressed == null ? AppColors.muted : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      'info_requested' => AppColors.warn,
      'reviewing' => AppColors.coralLight,
      'pending' => AppColors.ink,
      _ => AppColors.muted,
    };

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item, required this.onCancel});

  final AuctionRequest item;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  AuctionRequest.statusLabel(item.status),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          Text(
            [
              if (item.category != null) item.category!,
              if (item.startPrice != null) formatMnt(item.startPrice!),
              DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt.toLocal()),
            ].join(' · '),
            style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkSoft,
                fontFeatures: [FontFeature.tabularFigures()]),
          ),
          if (item.adminNote != null && item.adminNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.messageSquare,
                      size: 14, color: AppColors.coralLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.adminNote!,
                        style: const TextStyle(
                            fontSize: 13, height: 1.45, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ],
          if (item.canCancel) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedPressable(
                onPressed: onCancel,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Text('Цуцлах',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Хүсэлтийг цуцлах уу?',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            '“$title” хүсэлт цуцлагдана. Үүнийг буцаах боломжгүй.',
            style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Цуцлах',
            gradient: AppColors.dangerGradient,
            foreground: AppColors.ctaInk,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 12),
          _GhostButton(
            label: 'Болих',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}
