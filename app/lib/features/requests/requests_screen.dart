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

  Future<void> _pickCategory() async {
    FocusScope.of(context).unfocus();
    final picked = await showAppSheet<String>(
      context,
      builder: (ctx) => _CategorySheet(selected: _category),
    );
    if (picked == null) return;
    setState(() => _category = picked == _category ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final history = ref.watch(myRequestsProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final wide = Breakpoints.isWide(context);
    final bottom = (wide ? 40.0 : NavMetrics.bottomInset(context)) + viewInsets;
    final firstError = _titleError ?? _descError ?? _priceError;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: PageFrame(
          maxWidth: 720,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Хүсэлт', style: text.headlineMedium),
              ),
              const SizedBox(height: 6),
              const _Footnote(
                'Бараагаа дуудлага худалдаанд оруулах хүсэлт илгээнэ үү. '
                'Бид хянаад холбогдоно.',
              ),
              const SizedBox(height: 20),
              ErrorBanner(message: _formError, shakeToken: _shake),
              const _SectionHeader('Барааны мэдээлэл'),
              _Group(children: [
                _InputRow(
                  controller: _title,
                  hint: 'Нэр',
                  maxLength: 120,
                  invalid: _titleError != null,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _revalidate(),
                ),
                _ChoiceRow(
                  label: 'Ангилал',
                  value: _category,
                  enabled: !_loading,
                  onTap: _pickCategory,
                ),
                _InputRow(
                  controller: _description,
                  hint: 'Тайлбар — байдал, жил, дутагдал, багцад юу орох',
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 4000,
                  invalid: _descError != null,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _revalidate(),
                ),
                _InputRow(
                  controller: _price,
                  hint: 'Эхлэх үнэ',
                  prefixLabel: 'Эхлэх үнэ',
                  suffixText: '₮',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 12,
                  invalid: _priceError != null,
                  enabled: !_loading,
                  onChanged: (_) => _revalidate(),
                ),
              ]),
              if (firstError != null)
                _Footnote(firstError, color: AppColors.danger)
              else
                _Footnote(
                    'Тайлбар: ${_description.text.characters.length} / 4000'),
              const SizedBox(height: 20),
              const _SectionHeader('Бусад мэдээлэл'),
              _Group(children: [
                _InputRow(
                  controller: _preferred,
                  hint: 'Тохиромжтой хугацаа',
                  maxLength: 120,
                  enabled: !_loading,
                ),
                _InputRow(
                  controller: _other,
                  hint: 'Нэмэлт мэдээлэл',
                  maxLines: 4,
                  minLines: 3,
                  maxLength: 2000,
                  enabled: !_loading,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ]),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Илгээх',
                loading: _loading,
                onPressed: _loading ? null : () => _submit(draft: false),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : () => _submit(draft: true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    minimumSize: const Size(44, 44),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Ноорог хадгалах'),
                ),
              ),
              const SizedBox(height: 28),
              const _SectionHeader('Миний хүсэлтүүд'),
              history.when(
                loading: () => const Column(children: [
                  Skeleton(height: 64, radius: 16),
                  SizedBox(height: 8),
                  Skeleton(height: 64, radius: 16),
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
                    ? const EmptyState(
                        icon: LucideIcons.filePlus2,
                        title: 'Хүсэлт хараахан алга',
                        subtitle: 'Илгээсэн хүсэлт энд харагдана.',
                      )
                    : _Group(children: [
                        for (final r in list)
                          _RequestRow(
                            item: r,
                            onCancel: () => unawaited(_cancel(r)),
                          ),
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(text,
          style: TextStyle(
              fontSize: 13, height: 1.4, color: color ?? AppColors.muted)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.muted)),
    );
  }
}

/// iOS grouped inset карт — мөрүүдийн хооронд 0.5px зааг.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child:
                  Divider(height: 0.5, thickness: 0.5, color: AppColors.border),
            ),
          children[i],
        ],
      ]),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.hint,
    this.prefixLabel,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.invalid = false,
    this.enabled = true,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String? prefixLabel;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool invalid;
  final bool enabled;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final inline = prefixLabel != null;
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      textAlign: inline ? TextAlign.end : TextAlign.start,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      cursorColor: AppColors.accent,
      style: TextStyle(fontSize: 17, color: AppColors.ink),
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      decoration: InputDecoration.collapsed(
        hintText: inline ? '0' : hint,
        hintStyle: TextStyle(fontSize: 17, color: AppColors.muted),
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      color: invalid ? AppColors.dangerBg : null,
      child: inline
          ? Row(children: [
              Text(prefixLabel!,
                  style: TextStyle(fontSize: 17, color: AppColors.ink)),
              const SizedBox(width: 12),
              Expanded(child: field),
              if (suffixText != null) ...[
                const SizedBox(width: 4),
                Text(suffixText!,
                    style: TextStyle(fontSize: 17, color: AppColors.muted)),
              ],
            ])
          : field,
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(label, style: TextStyle(fontSize: 17, color: AppColors.ink)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? 'Сонгох',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text('Ангилал',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (var i = 0; i < _categories.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Divider(
                          height: 0.5, thickness: 0.5, color: AppColors.border),
                    ),
                  InkWell(
                    onTap: () => Navigator.pop(context, _categories[i]),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 50),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(
                          child: Text(_categories[i],
                              style: TextStyle(
                                  fontSize: 17, color: AppColors.ink)),
                        ),
                        if (_categories[i] == selected)
                          Icon(LucideIcons.check,
                              size: 20, color: AppColors.accent),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
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

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.item, required this.onCancel});

  final AuctionRequest item;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    final note = item.adminNote?.trim() ?? '';
    final footnote =
        TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              Text(
                AuctionRequest.statusLabel(item.status),
                style: TextStyle(fontSize: 15, color: color),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (item.category != null) item.category!,
              if (item.startPrice != null) formatMnt(item.startPrice!),
              DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt.toLocal()),
            ].join(' · '),
            style: footnote,
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(note, style: footnote),
          ],
          if (item.canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Цуцлах'),
              ),
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
