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
    final typeError = _type == null ? 'Төрлөө сонгоно уу' : null;
    final categoryError = _category == null ? 'Ангиллаа сонгоно уу' : null;
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
    final text = Theme.of(context).textTheme;
    final history = ref.watch(myFeedbackProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Санал хүсэлт', style: text.displaySmall),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: PageFrame(
            maxWidth: 720,
            child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + viewInsets),
            children: [
              Text(
                'Юуг сайжруулах ёстойг хэлж өгөөрэй. Санал бүрийг уншиж, '
                'дараагийн хувилбарт тусгана.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 26),
              ErrorBanner(message: _formError, shakeToken: _shake),

              const SectionLabel('Төрөл'),
              const SizedBox(height: 12),
              Shake(
                token: _typeError == null ? 0 : _shake,
                child: AppChoiceChips<String>(
                  options: FeedbackMeta.types
                      .map((t) => ChipOption(t.id, t.label, icon: _typeIcons[t.id]))
                      .toList(),
                  selected: _type,
                  onSelected: (v) => setState(() {
                    _type = v;
                    _typeError = null;
                  }),
                ),
              ),
              FieldMessage(error: _typeError),

              const SizedBox(height: 24),
              const SectionLabel('Ангилал'),
              const SizedBox(height: 12),
              Shake(
                token: _categoryError == null ? 0 : _shake,
                child: AppChoiceChips<String>(
                  options: FeedbackMeta.categories
                      .map((c) =>
                          ChipOption(c.id, c.label, icon: _categoryIcons[c.id]))
                      .toList(),
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
                hint: 'Юу болсныг, хаана болсныг аль болох тодорхой бичнэ үү.',
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
                    setState(() =>
                        _messageError = Validators.feedbackMessage(_message.text));
                  }
                },
              ),

              const SizedBox(height: 26),
              PrimaryButton(
                label: 'Илгээх',
                icon: LucideIcons.send,
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),

              const SizedBox(height: 34),
              const SectionLabel('Миний илгээсэн'),
              const SizedBox(height: 12),
              history.when(
                loading: () => const Column(
                  children: [
                    Skeleton(height: 74, radius: 18),
                    SizedBox(height: 10),
                    Skeleton(height: 74, radius: 18),
                  ],
                ),
                error: (e, _) => Text(apiErrorMessage(e), style: text.bodySmall),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.messageSquare,
                        title: 'Одоогоор санал алга',
                        subtitle: 'Илгээсэн санал тань энд түүхээрээ хадгалагдана.',
                      )
                    : Column(
                        children: list
                            .map((f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _FeedbackTile(item: f),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});

  final FeedbackItem item;

  Color get _statusColor => switch (item.status) {
        'resolved' => AppColors.success,
        'reviewing' => AppColors.warn,
        'closed' => AppColors.muted,
        _ => AppColors.ink,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_typeIcons[item.type] ?? LucideIcons.messageSquare,
                  size: 15, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${FeedbackMeta.typeLabel(item.type)} · '
                  '${FeedbackMeta.categoryLabel(item.category)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  FeedbackMeta.statusLabel(item.status),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.inkSoft),
          ),
          if (item.adminNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceHi,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.messageSquare,
                      size: 13, color: AppColors.ink),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.adminNote!,
                      style: const TextStyle(
                          fontSize: 12.5, height: 1.45, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${item.createdAt.toLocal()}'.substring(0, 16),
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
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
          Text('Хүлээж авлаа',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Санал тань бүртгэгдлээ. Хариуг доорх түүхээс хараарай.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Ойлголоо',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
