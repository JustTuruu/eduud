import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/responsive.dart';
import '../../shared/widgets.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

class _FaqGroup {
  const _FaqGroup(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<_Faq> items;
}

/// Тусламжийн агуулга апп дотор шууд байрлана — сервер унасан ч хэрэглэгч
/// хариултаа олж чадна.
const _groups = [
  _FaqGroup('Дуудлага худалдаа', LucideIcons.gavel, [
    _Faq(
      'Энэ дуудлага худалдаа яаж ажилладаг вэ?',
      'Үнэ илгээх бүрт 1 эрх зарцуулж, барааны үнийг бага зэрэг өсгөнө. '
          'Хугацаа дуусахад хамгийн сүүлд үнэ илгээсэн хүн ялна. Ялагч эцсийн '
          'үнийг төлж бараагаа авна.',
    ),
    _Faq(
      'Хугацаа дуусахад яагаад нэмэгдэв?',
      'Сүүлийн секундэд санал орвол бүгдэд тэгш боломж олгохын тулд '
          'хугацаа өөрөө бага зэрэг сунгагдана.',
    ),
    _Faq(
      'Өгсөн санал буцаагдах уу?',
      'Зарцуулсан эрх буцаагдахгүй. Харин техникийн алдаанаас болж '
          'санал бүртгэгдээгүй бол эрх тань өөрөө буцаагдана.',
    ),
  ]),
  _FaqGroup('Эрх ба төлбөр', LucideIcons.ticket, [
    _Faq(
      'Эрх яаж авах вэ?',
      'Эрх цэнэглэх хэсгээс багцаа сонгоод банкны апп-аараа QR уншуулж төлнө. '
          'Төлбөр ормогц эрх тань шууд нэмэгдэнэ.',
    ),
    _Faq(
      'Төлсөн боловч эрх орж ирсэнгүй.',
      'Төлбөрийн цонхон дахь "Төлбөр шалгах" товчийг дарна уу. 10 минутын '
          'дараа ч орж ирэхгүй бол Санал хүсэлт хэсгээр "Төлбөр" ангиллаар '
          'бидэнд мэдэгдээрэй.',
    ),
    _Faq(
      'Хожсон барааныхаа төлбөрийг хэзээ төлөх вэ?',
      'Хожсноос хойш 24 цагийн дотор төлнө. Хугацаа хэтэрвэл бараа '
          'танд олгогдохгүй.',
    ),
  ]),
  _FaqGroup('Бүртгэл ба нууцлал', LucideIcons.shieldCheck, [
    _Faq(
      'Баталгаажуулах код ирэхгүй байна.',
      'Дугаараа зөв эсэхийг шалгаад 60 секундын дараа дахин код авна уу. '
          'Нэг өдөрт 5 удаа код авах боломжтой.',
    ),
    _Faq(
      'Нууц үгээ мартсан.',
      'Нэвтрэх дэлгэц дээрх "Нууц үгээ мартсан уу?" холбоосоор орж, дугаараа '
          'баталгаажуулаад шинэ нууц үг тохируулна. Аюулгүй байдлын үүднээс бүх '
          'төхөөрөмжөөс гарна.',
    ),
    _Faq(
      'Бүртгэлээ устгаж болох уу?',
      'Санал хүсэлт хэсгээр "Бусад" төрлөөр хүсэлт илгээнэ үү. Бид дугаараа '
          'баталгаажуулсны дараа устгана.',
    ),
  ]),
];

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Тусламж'),
        leading: const AppBackButton(),
      ),
      body: SafeArea(
        top: false,
        child: PageFrame(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
            children: [
              for (final group in _groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                  child: Text(group.title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                ),
                _Card(
                    children: [for (final f in group.items) _FaqTile(faq: f)]),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 32, 4, 8),
                child: Text('Хариултаа олсонгүй юу?', style: text.displaySmall),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                child: Text(
                  'Алдаа, санал, гомдол — юу ч бай бичээрэй, бид хариу өгнө.',
                  style: TextStyle(
                      fontSize: 15, height: 1.4, color: AppColors.muted),
                ),
              ),
              PrimaryButton(
                label: 'Санал хүсэлт илгээх',
                onPressed: () => context.push('/feedback'),
              ),
              const SizedBox(height: 24),
              _Card(children: [
                _LinkRow(
                  icon: LucideIcons.fileText,
                  label: 'Үйлчилгээний нөхцөл',
                  onTap: () => context.push('/content/terms'),
                ),
                _LinkRow(
                  icon: LucideIcons.shieldCheck,
                  label: 'Нууцлалын бодлого',
                  onTap: () => context.push('/content/privacy'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS grouped inset карт — мөрүүдийн хооронд 0.5px зааг.
class _Card extends StatelessWidget {
  const _Card({required this.children});

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

/// Дэлгэгддэг асуулт. Нээгдэхэд хариулт зөөлөн тэлж, сум эргэнэ.
/// Screen reader-т нээлттэй/хаалттай төлөв уншигдана.
class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final reduce = reducedMotion(context);
    final dur = reduce ? Duration.zero : AppMotion.base;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.faq.question,
                        style: TextStyle(
                            fontSize: 17, height: 1.3, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: _open ? 0.25 : 0,
                      duration: dur,
                      curve: AppMotion.enter,
                      child: Icon(LucideIcons.chevronRight,
                          size: 18, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: dur,
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    widget.faq.answer,
                    style: TextStyle(
                        fontSize: 15, height: 1.45, color: AppColors.muted),
                  ),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 17, color: AppColors.ink)),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
