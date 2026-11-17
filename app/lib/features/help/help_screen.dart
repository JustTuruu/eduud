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
      'Санал бүр 1 эрх зарцуулж, барааны үнийг бага зэрэг өсгөнө. '
          'Хугацаа дуусахад хамгийн сүүлд санал өгсөн хүн ялна. Ялагч эцсийн '
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const AppBackButton(),
      ),
      body: AppBackground(
        seed: 'help',
        child: SafeArea(
          top: false,
          child: PageFrame(
            maxWidth: 640,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 64),
              children: [
                const Text(
                  'Тусламж',
                  style: TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Түгээмэл асуултууд. Хариултаа олохгүй бол доороос бидэнд бичээрэй.',
                  style: TextStyle(
                      fontSize: 15, height: 1.5, color: AppColors.inkSoft),
                ),
                for (final group in _groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 4),
                    child: Row(children: [
                      Icon(group.icon, size: 18, color: AppColors.coralLight),
                      const SizedBox(width: 10),
                      Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ]),
                  ),
                  for (final f in group.items) _FaqTile(faq: f),
                ],
                const Padding(
                  padding: EdgeInsets.only(top: 40, bottom: 8),
                  child: Text(
                    'Хариултаа олсонгүй юу?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const Text(
                  'Алдаа, санал, гомдол — юу ч бай бичээрэй, бид хариу өгнө.',
                  style: TextStyle(
                      fontSize: 15, height: 1.5, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Санал хүсэлт илгээх',
                  icon: LucideIcons.send,
                  onPressed: () => context.push('/feedback'),
                ),
                const SizedBox(height: 32),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Дэлгэгддэг асуулт — зөвхөн хацар шугамтай мөр. Нээгдэхэд хариулт зөөлөн
/// тэлж, сум эргэнэ. Screen reader-т нээлттэй/хаалттай төлөв уншигдана.
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
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.faq.question,
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: dur,
                        curve: AppMotion.enter,
                        child: const Icon(LucideIcons.chevronDown,
                            size: 20, color: AppColors.inkSoft),
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
                    padding: const EdgeInsets.only(bottom: 18, right: 32),
                    child: Text(
                      widget.faq.answer,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.65,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
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
          constraints: const BoxConstraints(minHeight: 56),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 18, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
