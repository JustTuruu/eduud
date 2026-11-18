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
import '../../shared/top_toast.dart';

final myRequestsProvider =
    FutureProvider.autoDispose<List<AuctionRequest>>((ref) async {
  final res = await ref.watch(dioProvider).get('/auction-requests/mine');
  return (res.data as List)
      .map((e) => AuctionRequest.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Ангилал: backend-ээс (GET /categories), алдаа гарвал доорх жагсаалт.
final requestCategoriesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/categories');
    final names = [
      for (final e in res.data as List)
        if (e is Map && e['name'] != null) e['name'].toString()
    ];
    return names.isEmpty ? _categories : names;
  } catch (_) {
    return _categories;
  }
});

const _categories = [
  'Электроник',
  'Гэр ахуй',
  'Хувцас',
  'Тээврийн хэрэгсэл',
  'Бусад',
];

/// Хүсэлт — дээр нь тойм (шинэ хүсэлт илгээх + миний хүсэлтүүд),
/// маягтыг бүтэн дэлгэцээр нээнэ.
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  Future<void> _openForm(BuildContext context, {AuctionRequest? edit}) async {
    final msg = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RequestFormPage(initial: edit),
      ),
    );
    if (msg == null || !context.mounted) return;
    showTopToast(context, msg, kind: TopToastKind.success);
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, AuctionRequest r) async {
    final ok = await showAppSheet<bool>(
      context,
      builder: (ctx) => _CancelSheet(title: r.title),
    );
    if (ok != true) return;
    try {
      await ref.read(dioProvider).post('/auction-requests/${r.id}/cancel');
      ref.invalidate(myRequestsProvider);
      if (!context.mounted) return;
      showTopToast(context, 'Хүсэлт цуцлагдлаа.', kind: TopToastKind.success);
    } catch (e) {
      if (!context.mounted) return;
      showTopToast(context, apiErrorMessage(e), kind: TopToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final history = ref.watch(myRequestsProvider);
    final wide = Breakpoints.isWide(context);
    final bottom = wide ? 40.0 : NavMetrics.bottomInset(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: PageFrame(
          maxWidth: 720,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Хүсэлт', style: text.headlineMedium),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Бараагаа дуудлага худалдаанд оруулах хүсэлт',
                  style: TextStyle(fontSize: 15, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 20),
              _NewRequestCard(onTap: () => _openForm(context)),
              const SizedBox(height: 28),
              history.when(
                loading: () => const Column(children: [
                  Skeleton(height: 72, radius: 16),
                  SizedBox(height: 8),
                  Skeleton(height: 72, radius: 16),
                ]),
                error: (e, _) => Column(children: [
                  Text(apiErrorMessage(e),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(myRequestsProvider),
                    child: const Text('Дахин оролдох'),
                  ),
                ]),
                data: (list) => list.isEmpty
                    ? const _HowItWorks()
                    : GroupSection(
                        title: 'Миний хүсэлтүүд',
                        children: [
                          for (final r in list)
                            _RequestRow(
                              item: r,
                              onEdit: r.canEdit
                                  ? () => _openForm(context, edit: r)
                                  : null,
                              onCancel: () =>
                                  unawaited(_cancel(context, ref, r)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Шинэ хүсэлт илгээх том карт.
class _NewRequestCard extends StatelessWidget {
  const _NewRequestCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Шинэ хүсэлт илгээх',
      child: AnimatedPressable(
        onPressed: onTap,
        scale: 0.985,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(LucideIcons.plus, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Шинэ хүсэлт илгээх',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Бид хянаад 1–2 хоногт хариу өгнө',
                      style: TextStyle(fontSize: 13, color: Color(0xCCFFFFFF))),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// Хүсэлт байхгүй үед — үйл явцын 3 алхам.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Барааныхаа мэдээллийг илгээнэ',
    'Бид хянаж, шаардлагатай бол холбогдоно',
    'Зөвшөөрөгдвөл дуудлага худалдаанд гарна',
  ];

  @override
  Widget build(BuildContext context) {
    return GroupSection(
      title: 'Хэрхэн явагддаг вэ',
      children: [
        for (var i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.14),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(_steps[i],
                    style: TextStyle(
                        fontSize: 16, height: 1.3, color: AppColors.ink)),
              ),
            ]),
          ),
      ],
    );
  }
}

Color _statusColor(String s) => switch (s) {
      'approved' => AppColors.success,
      'rejected' => AppColors.danger,
      'pending' || 'info_requested' => AppColors.warn,
      'reviewing' => const Color(0xFF0A84FF),
      _ => AppColors.muted,
    };

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        AuctionRequest.statusLabel(status),
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.item,
    required this.onCancel,
    this.onEdit,
  });

  final AuctionRequest item;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final note = item.adminNote?.trim() ?? '';
    final meta = TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted);
    final actionStyle = TextButton.styleFrom(
      minimumSize: const Size(44, 36),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(item.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (item.category != null) item.category!,
              if (item.startPrice != null) formatMnt(item.startPrice!),
              DateFormat('yyyy.MM.dd').format(item.createdAt.toLocal()),
            ].join(' · '),
            style: meta,
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(color: AppColors.borderHi, width: 2)),
              ),
              child: Text('“$note”',
                  style: meta.copyWith(fontStyle: FontStyle.italic)),
            ),
          ],
          if (onEdit != null || item.canCancel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                if (onEdit != null)
                  TextButton(
                    onPressed: onEdit,
                    style: actionStyle.copyWith(
                        foregroundColor:
                            WidgetStatePropertyAll(AppColors.accent)),
                    child: Text(
                        item.status == 'draft' ? 'Засаад илгээх' : 'Засах'),
                  ),
                const Spacer(),
                if (item.canCancel)
                  TextButton(
                    onPressed: onCancel,
                    style: actionStyle.copyWith(
                        foregroundColor:
                            WidgetStatePropertyAll(AppColors.danger)),
                    child: const Text('Цуцлах'),
                  ),
              ]),
            ),
          if (onEdit == null && !item.canCancel) const SizedBox(height: 4),
        ],
      ),
    );
    if (onEdit == null) return content;
    return Semantics(
      button: true,
      label: item.title,
      child: AnimatedPressable(onPressed: onEdit, scale: 0.99, child: content),
    );
  }
}

// ---------------------------------------------------------------------------
// Маягт
// ---------------------------------------------------------------------------

/// Цифрыг мянгатаар бүлэглэж харуулна (1 250 000). Утга нь зөвхөн цифр.
class _ThousandsFormatter extends TextInputFormatter {
  static String group(String digits) {
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
      b.write(digits[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = group(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _RequestFormPage extends ConsumerStatefulWidget {
  const _RequestFormPage({this.initial});

  /// Засах ноорог (эсвэл мэдээлэл дутуу хүсэлт). null бол шинэ хүсэлт.
  final AuctionRequest? initial;

  @override
  ConsumerState<_RequestFormPage> createState() => _RequestFormPageState();
}

class _RequestFormPageState extends ConsumerState<_RequestFormPage> {
  static const _quickDates = [
    'Энэ долоо хоногт',
    'Дараа долоо хоногт',
    'Хамаагүй',
  ];

  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description =
      TextEditingController(text: widget.initial?.description);
  late final _price = TextEditingController(
      text: widget.initial?.startPrice == null
          ? ''
          : _ThousandsFormatter.group('${widget.initial!.startPrice}'));
  late final _preferred =
      TextEditingController(text: widget.initial?.preferredDate);
  late final _other = TextEditingController(text: widget.initial?.otherInfo);

  final _titleFocus = FocusNode();
  final _descFocus = FocusNode();
  final _priceFocus = FocusNode();

  late String? _category = widget.initial?.category;
  bool _loading = false;
  int _shake = 0;
  String? _formError;

  // Талбар бүрийн алдааг зөвхөн нэг удаа орхисны дараа эсвэл илгээх үед үзүүлнэ.
  bool _titleTouched = false;
  bool _descTouched = false;
  bool _priceTouched = false;

  bool get _editing => widget.initial != null;

  String get _priceDigits => _price.text.replaceAll(RegExp(r'\D'), '');

  String? get _titleError =>
      _titleTouched ? RequestValidators.title(_title.text) : null;
  String? get _descError =>
      _descTouched ? RequestValidators.description(_description.text) : null;
  String? get _priceError =>
      _priceTouched ? RequestValidators.startPrice(_priceDigits) : null;

  bool get _dirty {
    final i = widget.initial;
    String v(String? s) => (s ?? '').trim();
    return v(_title.text) != v(i?.title) ||
        v(_description.text) != v(i?.description) ||
        _priceDigits != (i?.startPrice?.toString() ?? '') ||
        v(_preferred.text) != v(i?.preferredDate) ||
        v(_other.text) != v(i?.otherInfo) ||
        _category != i?.category;
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _description, _price, _preferred, _other]) {
      c.addListener(_rebuild);
    }
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) setState(() => _titleTouched = true);
    });
    _descFocus.addListener(() {
      if (!_descFocus.hasFocus) setState(() => _descTouched = true);
    });
    _priceFocus.addListener(() {
      if (!_priceFocus.hasFocus) setState(() => _priceTouched = true);
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _preferred, _other]) {
      c.dispose();
    }
    _titleFocus.dispose();
    _descFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _titleTouched = _descTouched = _priceTouched = true;
      _formError = null;
    });
    final ok = RequestValidators.title(_title.text) == null &&
        RequestValidators.description(_description.text) == null &&
        RequestValidators.startPrice(_priceDigits) == null;
    if (!ok) setState(() => _shake++);
    return ok;
  }

  Future<void> _submit({required bool draft}) async {
    if (!_validate()) return;
    setState(() => _loading = true);
    String? opt(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    final body = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      if (_category != null) 'category': _category,
      if (_priceDigits.isNotEmpty) 'startPrice': int.parse(_priceDigits),
      if (opt(_preferred) != null) 'preferredDate': opt(_preferred),
      if (opt(_other) != null) 'otherInfo': opt(_other),
    };
    try {
      final dio = ref.read(dioProvider);
      if (_editing) {
        await dio.patch('/auction-requests/${widget.initial!.id}',
            data: {...body, if (!draft) 'submit': true});
      } else {
        await dio.post('/auction-requests',
            data: {...body, if (draft) 'draft': true});
      }
      ref.invalidate(myRequestsProvider);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(draft
          ? 'Ноорог хадгалагдлаа.'
          : 'Хүсэлт илгээгдлээ. Бид хянаад холбогдоно.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _formError = apiErrorMessage(e);
        _shake++;
      });
    }
  }

  Future<void> _close() async {
    FocusScope.of(context).unfocus();
    if (!_dirty || _loading) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showAppSheet<bool>(
      context,
      builder: (ctx) => const _DiscardSheet(),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          leadingWidth: 92,
          leading: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _close,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                textStyle: const TextStyle(fontSize: 17),
              ),
              child: const Text('Болих'),
            ),
          ),
          title: Text(_editing ? 'Хүсэлт засах' : 'Шинэ хүсэлт'),
        ),
        bottomNavigationBar: _ActionBar(
          loading: _loading,
          draftLabel: widget.initial?.status == 'info_requested'
              ? 'Хадгалах'
              : 'Ноорог болгож хадгалах',
          onSend: () => _submit(draft: false),
          onDraft: () => _submit(draft: true),
        ),
        body: PageFrame(
          maxWidth: 720,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 8, 16, wide ? 40 : 24),
            children: [
              ErrorBanner(message: _formError, shakeToken: _shake),
              const _SectionTitle('Бараа'),
              _FieldCard(
                label: 'Барааны нэр',
                required: true,
                error: _titleError,
                child: _plainField(
                  controller: _title,
                  focusNode: _titleFocus,
                  hint: 'Жишээ: iPhone 15 Pro 256GB',
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: 12),
              _FieldCard(
                label: 'Ангилал',
                child: AppChoiceChips<String>(
                  options: [
                    for (final c in ref.watch(requestCategoriesProvider).valueOrNull ??
                        _categories)
                      ChipOption(c, c)
                  ],
                  selected: _category,
                  onSelected: (v) {
                    if (_loading) return;
                    FocusScope.of(context).unfocus();
                    setState(() => _category = v == _category ? null : v);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _FieldCard(
                label: 'Тайлбар',
                required: true,
                error: _descError,
                footer: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_description.text.characters.length} / 4000',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                child: _plainField(
                  controller: _description,
                  focusNode: _descFocus,
                  hint: 'Байдал, жил, дутагдал, багцад юу орохыг бичнэ үү',
                  maxLines: 8,
                  minLines: 4,
                  maxLength: 4000,
                ),
              ),
              const _SectionTitle('Үнэ ба хугацаа'),
              _FieldCard(
                label: 'Хүссэн эхлэх үнэ',
                error: _priceError,
                child: Row(children: [
                  Expanded(
                    child: _plainField(
                      controller: _price,
                      focusNode: _priceFocus,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                        _ThousandsFormatter(),
                      ],
                    ),
                  ),
                  Text('₮',
                      style: TextStyle(fontSize: 17, color: AppColors.muted)),
                ]),
              ),
              const SizedBox(height: 12),
              _FieldCard(
                label: 'Тохиромжтой хугацаа',
                footer: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final q in _quickDates)
                    _QuickChip(
                      label: q,
                      selected: _preferred.text.trim() == q,
                      onTap: _loading ? null : () => _preferred.text = q,
                    ),
                ]),
                child: _plainField(
                  controller: _preferred,
                  hint: 'Жишээ: 12 сарын 20-ны дотор',
                  maxLength: 120,
                ),
              ),
              const _SectionTitle('Нэмэлт'),
              _FieldCard(
                label: 'Нэмэлт мэдээлэл',
                child: _plainField(
                  controller: _other,
                  hint: 'Бидэнд мэдэгдэх өөр зүйл байвал бичнэ үү',
                  maxLines: 6,
                  minLines: 3,
                  maxLength: 2000,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainField({
    required TextEditingController controller,
    required String hint,
    FocusNode? focusNode,
    int? maxLength,
    int maxLines = 1,
    int? minLines,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: !_loading,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      textInputAction: textInputAction,
      textCapitalization: keyboardType == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      cursorColor: AppColors.accent,
      style: TextStyle(fontSize: 17, color: AppColors.ink),
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration.collapsed(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 17, color: AppColors.muted),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.muted)),
    );
  }
}

/// Дээрээ тод шошготой, доор нь алдаа / нэмэлт зүйлтэй талбарын карт.
class _FieldCard extends StatelessWidget {
  const _FieldCard({
    required this.label,
    required this.child,
    this.required = false,
    this.error,
    this.footer,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? error;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: error != null
            ? Color.alphaBlend(AppColors.dangerBg, AppColors.surface)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
              TextSpan(children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                      text: ' *', style: TextStyle(color: AppColors.danger)),
              ]),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 8),
          child,
          if (footer != null) ...[const SizedBox(height: 10), footer!],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!,
                style: TextStyle(fontSize: 13, color: AppColors.danger)),
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedPressable(
        onPressed: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : AppColors.fill,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.accent : AppColors.inkSoft)),
        ),
      ),
    );
  }
}

/// Доор бэхлэгдсэн үйлдлийн мөр.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.loading,
    required this.draftLabel,
    required this.onSend,
    required this.onDraft,
  });

  final bool loading;
  final String draftLabel;
  final VoidCallback onSend;
  final VoidCallback onDraft;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        // heightFactor: 1 — үгүй бол Align бүх өндрийг эзэлж маягтыг дарна.
        child: Align(
          heightFactor: 1,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                PrimaryButton(
                  label: 'Илгээх',
                  loading: loading,
                  onPressed: loading ? null : onSend,
                ),
                TextButton(
                  onPressed: loading ? null : onDraft,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: Text(draftLabel),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscardSheet extends StatelessWidget {
  const _DiscardSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Хадгалахгүй гарах уу?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            'Бичсэн зүйл тань устах болно.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Гарах',
            gradient: AppColors.dangerGradient,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Үргэлжлүүлэх',
            onPressed: () => Navigator.pop(context, false),
          ),
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
          20, 20, 20, 16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Хүсэлтийг цуцлах уу?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text(
            '“$title” хүсэлт цуцлагдана. Үүнийг буцаах боломжгүй.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Цуцлах',
            gradient: AppColors.dangerGradient,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Болих',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}
