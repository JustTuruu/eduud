import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/form_widgets.dart';
import '../../shared/validators.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';
import '../wallet/sub_page.dart';
import 'package:intl/intl.dart';

final myFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) async {
  final res = await ref.watch(dioProvider).get('/feedback/mine');
  return (res.data as List)
      .map((e) => FeedbackItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _typeIcons = {
  'bug': LucideIcons.bug,
  'idea': LucideIcons.lightbulb,
  'improvement': LucideIcons.sparkles,
  'complaint': LucideIcons.triangleAlert,
  'suggestion': LucideIcons.messageSquare,
  'praise': LucideIcons.heart,
  'other': LucideIcons.layers,
};

const _categoryIcons = {
  'design': LucideIcons.palette,
  'ux': LucideIcons.user,
  'performance': LucideIcons.zap,
  'reliability': LucideIcons.shieldCheck,
  'usability': LucideIcons.listChecks,
  'content': LucideIcons.fileText,
  'billing': LucideIcons.creditCard,
  'general': LucideIcons.layers,
};

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _message = TextEditingController();
  final _messageFocus = FocusNode();

  String? _type;
  String? _category;
  bool _loading = false;
  int _shake = 0;

  String? _formError;
  String? _typeError;
  String? _categoryError;
  String? _messageError;
  bool _messageTouched = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _message.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  Future<void> _submit() async {
    final typeError = _type == null ? 'Юу тухай бичихээ сонгоно уу' : null;
    final categoryError = _category == null ? 'Аль хэсэгт хамаарахыг сонгоно уу' : null;
    final messageError = Validators.feedbackMessage(_message.text);

    setState(() {
      _messageTouched = true;
      _typeError = typeError;
      _categoryError = categoryError;
      _messageError = messageError;
      _formError = null;
    });

    if (typeError != null || categoryError != null || messageError != null) {
      setState(() => _shake++);
      if (messageError != null && typeError == null && categoryError == null) {
        _messageFocus.requestFocus();
      }
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(dioProvider).post('/feedback', data: {
        'type': _type,
        'category': _category,
        'message': _message.text.trim(),
        'platform': _platform,
        'appVersion': '0.1.0',
      });
      ref.invalidate(myFeedbackProvider);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _type = null;
        _category = null;
        _messageTouched = false;
        _messageError = null;
        _message.clear();
      });
      _messageFocus.unfocus();
      await showAppDialog<void>(context, builder: (ctx) => const _ThanksDialog());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _formError = apiErrorMessage(e);
        _shake++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(myFeedbackProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        seed: 'feedback',
        child: SafeArea(
          bottom: false,
          child: PageFrame(
            maxWidth: 720,
            child: ListView(
              padding:
                  EdgeInsets.fromLTRB(20, 12, 20, 40 + safeBottom + viewInsets),
              children: [
                const SubPageHeader(title: 'Санал хүсэлт'),
                const SizedBox(height: 24),
                Reveal(
                  index: 0,
                  child: const Text(
                    'Юуг сайжруулах ёстойг хэлээрэй. Санал болгоныг бид уншина.',
                    style: TextStyle(
                        fontSize: 15, height: 1.5, color: AppColors.inkSoft),
                  ),
                ),
                const SizedBox(height: 28),
                ErrorBanner(message: _formError, shakeToken: _shake),
                Reveal(
                  index: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PlainLabel('Юу тухай вэ?'),
                      const SizedBox(height: 10),
                      Shake(
                        token: _typeError == null ? 0 : _shake,
                        child: _Choices(
                          options: [
                            for (final t in FeedbackMeta.types)
                              (t.id, t.label, _typeIcons[t.id]),
                          ],
                          selected: _type,
                          onSelected: (v) => setState(() {
                            _type = v;
                            _typeError = null;
                          }),
                        ),
                      ),
                      FieldMessage(error: _typeError),
                      const SizedBox(height: 24),
                      const PlainLabel('Аль хэсэгт хамаарах вэ?'),
                      const SizedBox(height: 10),
                      Shake(
                        token: _categoryError == null ? 0 : _shake,
                        child: _Choices(
                          options: [
                            for (final c in FeedbackMeta.categories)
                              (c.id, c.label, _categoryIcons[c.id]),
                          ],
                          selected: _category,
                          onSelected: (v) => setState(() {
                            _category = v;
                            _categoryError = null;
                          }),
                        ),
                      ),
                      FieldMessage(error: _categoryError),
                      const SizedBox(height: 24),
                      AppField(
                        label: 'Дэлгэрэнгүй',
                        controller: _message,
                        focusNode: _messageFocus,
                        hint: 'Юу болсныг, хаана болсныг тодорхой бичээрэй.',
                        error: _messageError,
                        helper: _messageError == null
                            ? '${_message.text.characters.length} / 2000'
                            : null,
                        maxLines: 7,
                        minLines: 5,
                        maxLength: 2000,
                        enabled: !_loading,
                        shakeToken: _shake,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_messageTouched) {
                            setState(() => _messageError =
                                Validators.feedbackMessage(_message.text));
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                        label: 'Илгээх',
                        icon: LucideIcons.send,
                        loading: _loading,
                        onPressed: _loading ? null : _submit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                const Text('Миний илгээсэн',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 8),
                history.when(
                  loading: () => const Column(children: [
                    Skeleton(height: 74, radius: 16),
                    SizedBox(height: 10),
                    Skeleton(height: 74, radius: 16),
                  ]),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      Expanded(
                        child: Text(apiErrorMessage(e),
                            style: const TextStyle(color: AppColors.inkSoft)),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(myFeedbackProvider),
                        child: const Text('Дахин оролдох',
                            style: TextStyle(
                                color: AppColors.coralLight,
                                fontWeight: FontWeight.w800)),
                      ),
                    ]),
                  ),
                  data: (list) => list.isEmpty
                      ? const EmptyState(
                          icon: LucideIcons.messageSquare,
                          title: 'Санал хараахан илгээгээгүй',
                          subtitle: 'Илгээсэн санал чинь энд харагдана.',
                        )
                      : Column(children: [
                          for (var i = 0; i < list.length; i++)
                            _FeedbackRow(
                                item: list[i], last: i == list.length - 1),
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

typedef _Option = (String, String, IconData?);

/// Сонголтын chip-үүд. Сонгосон нь шүрэн 16% дүүргэлт + шүрэн хүрээтэй
/// (одоогийн сонголтыг шүрэнээр тэмдэглэнэ).
class _Choices extends StatelessWidget {
  const _Choices(
      {required this.options, required this.selected, required this.onSelected});

  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          Semantics(
            button: true,
            selected: o.$1 == selected,
            label: o.$2,
            child: AnimatedPressable(
              onPressed: () => onSelected(o.$1),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.enter,
                constraints: const BoxConstraints(minHeight: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: o.$1 == selected
                      ? AppColors.coral.withValues(alpha: 0.16)
                      : AppColors.surface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                    color: o.$1 == selected
                        ? AppColors.coral.withValues(alpha: 0.6)
                        : AppColors.border,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (o.$3 != null) ...[
                    Icon(o.$3,
                        size: 16,
                        color: o.$1 == selected
                            ? AppColors.coralLight
                            : AppColors.inkSoft),
                    const SizedBox(width: 8),
                  ],
                  Text(o.$2,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            o.$1 == selected ? FontWeight.w800 : FontWeight.w600,
                        color: AppColors.ink,
                      )),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

final _fbDate = DateFormat('yyyy.MM.dd HH:mm');

/// Илгээсэн саналын мөр — хуваагчтай жагсаалт.
class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.item, required this.last});

  final FeedbackItem item;
  final bool last;

  Color get _statusColor => switch (item.status) {
        'resolved' => AppColors.success,
        'reviewing' => AppColors.warn,
        'closed' => AppColors.muted,
        _ => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_typeIcons[item.type] ?? LucideIcons.messageSquare,
                size: 16, color: AppColors.inkSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${FeedbackMeta.typeLabel(item.type)} · '
                '${FeedbackMeta.categoryLabel(item.category)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(FeedbackMeta.statusLabel(item.status),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _statusColor)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(item.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14, height: 1.5, color: AppColors.ink)),
          if (item.adminNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.reply,
                      size: 15, color: AppColors.coralLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.adminNote!,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(_fbDate.format(item.createdAt.toLocal()),
              style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.muted,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _ThanksDialog extends StatelessWidget {
  const _ThanksDialog();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: reducedMotion(context) ? 1 : 0.4, end: 1),
              duration: AppMotion.slow,
              curve: Curves.elasticOut,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successBg,
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.45)),
                ),
                child: const Icon(LucideIcons.check,
                    size: 30, color: AppColors.success),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Баярлалаа',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 8),
          const Text(
            'Санал чинь хүрлээ. Хариуг доорх жагсаалтаас харна.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'За',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
