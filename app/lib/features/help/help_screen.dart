import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
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
      'Дуудлага бүрд 1 token зарцуулагдаж, барааны үнэ бага хэмжээгээр өснө. '
          'Хугацаа дуусахад хамгийн сүүлд дуудсан хүн ялна. Ялагч эцсийн үнийг '
          'тусад нь төлж бараагаа авна.',
    ),
    _Faq(
      'Хугацаа дуусахад яагаад нэмэгдэв?',
      'Сүүлийн секундэд дуудлага орвол бүгдэд тэгш боломж олгохын тулд '
          'хугацаа автоматаар багахан хугацаагаар сунгагдана.',
    ),
    _Faq(
      'Дуудлага буцаагдах уу?',
      'Зарцуулсан token буцаагдахгүй. Харин техникийн алдаанаас болж '
          'дуудлага бүртгэгдээгүй бол token тань автоматаар буцаагдана.',
    ),
  ]),
  _FaqGroup('Token ба төлбөр', LucideIcons.gem, [
    _Faq(
      'Token яаж авах вэ?',
      'Данс хэсгээс багцаа сонгоод банкны апп-аараа QR уншуулж төлнө. '
          'Төлбөр баталгаажмагц token тань шууд нэмэгдэнэ.',
    ),
    _Faq(
      'Төлсөн боловч token орж ирэхгүй байна.',
      'Төлбөрийн цонхон дахь "Төлбөр шалгах" товчийг дарна уу. Хэрэв 10 минутын '
          'дараа ч орж ирэхгүй бол Санал хүсэлт хэсгээр дамжуулан "Төлбөр тооцоо" '
          'ангиллаар бидэнд мэдэгдээрэй.',
    ),
    _Faq(
      'Ялсан барааныхаа төлбөрийг хэзээ төлөх вэ?',
      'Ялсанаас хойш 24 цагийн дотор төлнө. Хугацаа хэтэрвэл захиалга '
          'цуцлагдана.',
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
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Тусламж', style: text.displaySmall),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              Text(
                'Түгээмэл асуултууд. Хариултаа олохгүй бол доод талаас бидэнд '
                'бичээрэй.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 24),
              for (final group in _groups) ...[
                Row(
                  children: [
                    Icon(group.icon, size: 15, color: AppColors.sapphireSoft),
                    const SizedBox(width: 9),
                    SectionLabel(group.title),
                  ],
                ),
                const SizedBox(height: 12),
                ...group.items.map((f) => _FaqTile(faq: f)),
                const SizedBox(height: 24),
              ],
              const SectionLabel('Хариултаа олсонгүй юу?'),
              const SizedBox(height: 12),
              GlowCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Бидэнд шууд бичээрэй', style: text.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Алдаа, санал, гомдол — юу ч бай бүртгэж, хариу өгнө.',
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(
                        label: 'Санал хүсэлт илгээх',
                        icon: LucideIcons.send,
                        onPressed: () => context.push('/feedback'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Бичиг баримт'),
              const SizedBox(height: 12),
              _LinkTile(
                icon: LucideIcons.fileText,
                label: 'Үйлчилгээний нөхцөл',
                onTap: () => context.push('/content/terms'),
              ),
              _LinkTile(
                icon: LucideIcons.shieldCheck,
                label: 'Нууцлалын бодлого',
                onTap: () => context.push('/content/privacy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Дэлгэгддэг асуулт. Хариулт нээгдэхэд зөөлөн тэлж, сум эргэнэ.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(
              color: _open ? AppColors.borderHi : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          expanded: _open,
                          child: Text(
                            widget.faq.question,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: AppMotion.fast,
                        curve: AppMotion.enter,
                        child: const Icon(LucideIcons.chevronDown,
                            size: 18, color: AppColors.muted),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: AppMotion.base,
                    curve: AppMotion.enter,
                    alignment: Alignment.topCenter,
                    child: _open
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12, right: 26),
                            child: Text(
                              widget.faq.answer,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.65,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedPressable(
        onPressed: onTap,
        scale: 0.98,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Icon(icon, size: 18, color: AppColors.sapphireSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.ink)),
            ),
            const Icon(LucideIcons.chevronRight, size: 17, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}
