import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

/// Анхдагч 11 раундын загвар (backend-ийн AuctionRounds.defaultSchedule-тэй ижил):
/// R1 3ц цонх/1ц; R2..R8 1ц цонх/45м,30м,20м,10м,5м,3м,1м; R9..R11 40м цонх/30с,10с,5с.
List<({DateTime start, DateTime end, int sec})> defaultRoundTemplate(
    DateTime start) {
  final out = <({DateTime start, DateTime end, int sec})>[];
  var t = start;
  void add(Duration window, int sec) {
    out.add((start: t, end: t.add(window), sec: sec));
    t = t.add(window);
  }

  add(const Duration(hours: 3), 3600);
  for (final s in const [2700, 1800, 1200, 600, 300, 180, 60]) {
    add(const Duration(hours: 1), s);
  }
  for (final s in const [30, 10, 5]) {
    add(const Duration(minutes: 40), s);
  }
  return out;
}

class _Round {
  _Round(this.start, this.end, int sec)
      : dur = TextEditingController(text: '$sec');
  DateTime? start, end;
  final TextEditingController dur;
}

final _fmt = DateFormat('yyyy-MM-dd HH:mm');

/// Огноо + цаг сонгох талбар.
class DateTimeField extends StatelessWidget {
  const DateTimeField(
      {super.key, required this.value, required this.onChanged});
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final init = value ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d == null || !context.mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(init));
    if (t == null) return;
    onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: const InputDecoration(
              suffixIcon: Icon(LucideIcons.calendar, size: 15)),
          child: Text(value == null ? 'Сонгох' : _fmt.format(value!),
              style: adminNumber(
                  size: 14,
                  color: value == null ? AdminColors.faint : AdminColors.ink)),
        ),
      );
}

/// Дуудлага үүсгэх/засах форм (самбар дотор). Зөвхөн draft засагдана.
class AuctionForm extends ConsumerStatefulWidget {
  const AuctionForm({super.key, this.initial});
  final Json? initial;

  @override
  ConsumerState<AuctionForm> createState() => _AuctionFormState();
}

class _AuctionFormState extends ConsumerState<AuctionForm> {
  late final _title = TextEditingController();
  late final _desc = TextEditingController();
  late final _price = TextEditingController(text: '1000');
  late final _inc = TextEditingController(text: '100');
  late final _soft = TextEditingController(text: '30');
  late final _extend = TextEditingController(text: '30');
  final List<TextEditingController> _images = [];
  final List<_Round> _rounds = [];
  DateTime? _start, _end;
  String? _categoryId;
  bool _useRounds = false;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a == null) return;
    _title.text = jStr(a, 'title');
    _desc.text = jStr(a, 'description');
    _price.text = '${jInt(a, 'startPrice')}';
    _inc.text = '${jInt(a, 'increment')}';
    _soft.text = '${jInt(a, 'softCloseSec')}';
    _extend.text = '${jInt(a, 'extendSec')}';
    _start = DateTime.tryParse(jStr(a, 'startsAt'))?.toLocal();
    _end = DateTime.tryParse(jStr(a, 'endsAt'))?.toLocal();
    _categoryId = a['categoryId']?.toString();
    final imgs = a['images'];
    if (imgs is List) {
      for (final i in imgs) {
        _images.add(TextEditingController(text: '$i'));
      }
    }
    final rs = a['rounds'];
    if (rs is List && rs.isNotEmpty) {
      _useRounds = true;
      for (final r in rs) {
        final m = Map<String, dynamic>.from(r as Map);
        _rounds.add(_Round(
            DateTime.tryParse(jStr(m, 'startsAt'))?.toLocal(),
            DateTime.tryParse(jStr(m, 'endsAt'))?.toLocal(),
            jInt(m, 'durationSec')));
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _inc, _soft, _extend, ..._images]) {
      c.dispose();
    }
    for (final r in _rounds) {
      r.dur.dispose();
    }
    super.dispose();
  }

  Future<void> _useTemplate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      helpText: 'Эхлэх өдрөө сонгоно уу',
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
    if (t == null) return;
    final start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      for (final r in _rounds) {
        r.dur.dispose();
      }
      _rounds
        ..clear()
        ..addAll([
          for (final r in defaultRoundTemplate(start))
            _Round(r.start, r.end, r.sec)
        ]);
    });
  }

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// Алдаа байвал мессеж, үгүй бол null; body-г бөглөнө.
  String? _validate(Json body) {
    final title = _title.text.trim();
    if (title.length < 3) return 'Нэр хамгийн багадаа 3 тэмдэгт байна.';
    final price = int.tryParse(_price.text.trim());
    if (price == null || price < 0) return 'Эхлэх үнийг зөв бичнэ үү.';
    final inc = int.tryParse(_inc.text.trim());
    if (inc == null || inc < 1) return 'Үнийн алхам 1-ээс багагүй байна.';
    final soft = int.tryParse(_soft.text.trim());
    final ext = int.tryParse(_extend.text.trim());
    if (soft == null || ext == null || soft < 0 || ext < 0) {
      return 'Сунгалтын секундийг зөв бичнэ үү.';
    }
    final images = [
      for (final c in _images)
        if (c.text.trim().isNotEmpty) c.text.trim()
    ];
    for (final u in images) {
      if (!u.startsWith('http')) {
        return 'Зураг http:// эсвэл https:// холбоос байна.';
      }
    }
    body.addAll({
      'title': title,
      'description': _desc.text.trim(),
      'images': images,
      'startPrice': price,
      'increment': inc,
      'softCloseSec': soft,
      'extendSec': ext,
      'categoryId': _categoryId ?? '',
    });
    if (_useRounds) {
      if (_rounds.isEmpty) return 'Дор хаяж нэг раунд нэмнэ үү.';
      final list = <Json>[];
      DateTime? prevEnd;
      for (var i = 0; i < _rounds.length; i++) {
        final r = _rounds[i];
        final n = 'Раунд ${i + 1}: ';
        final sec = int.tryParse(r.dur.text.trim());
        if (r.start == null || r.end == null) {
          return '$nэхлэх, дуусах цагаа сонгоно уу.';
        }
        if (sec == null || sec < 1) return '$nтоолуурын секунд буруу.';
        if (!r.start!.isBefore(r.end!)) {
          return '$nдуусах цаг эхлэхээс хойш байна.';
        }
        if (prevEnd != null && r.start!.isBefore(prevEnd)) {
          return '$nөмнөх раундтай давхцаж болохгүй.';
        }
        prevEnd = r.end;
        list.add({
          'startsAt': _iso(r.start!),
          'endsAt': _iso(r.end!),
          'durationSec': sec,
        });
      }
      body['rounds'] = list;
      body['startsAt'] = list.first['startsAt'];
      body['endsAt'] = list.last['endsAt'];
    } else {
      if (_start == null || _end == null) {
        return 'Эхлэх, дуусах цагаа сонгоно уу.';
      }
      if (!_end!.isAfter(_start!)) return 'Дуусах цаг эхлэхээс хойш байна.';
      body['startsAt'] = _iso(_start!);
      body['endsAt'] = _iso(_end!);
    }
    return null;
  }

  Future<void> _save() async {
    final body = <String, dynamic>{};
    final err = _validate(body);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final api = ref.read(adminApiProvider);
    final ok = await runAdminAction(
      context,
      () => _editing
          ? api.updateAuction(jStr(widget.initial!, 'id'), body)
          : api.createAuction(body),
      success: _editing ? 'Хадгаллаа' : 'Ноорог үүслээ. Нийтлэхээ мартуузай.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Widget _two(Widget a, Widget b) => LayoutBuilder(
        builder: (context, c) => c.maxWidth < 420
            ? Column(children: [a, b])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: a),
                const SizedBox(width: 12),
                Expanded(child: b),
              ]),
      );

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(adminCategoriesProvider).valueOrNull ?? const [];
    final catIds = cats.map((c) => c.id).toSet();
    return ListView(padding: const EdgeInsets.all(20), children: [
      FieldLabel('Нэр', child: TextField(controller: _title, maxLength: 120)),
      FieldLabel('Тайлбар',
          child: TextField(controller: _desc, maxLines: 4, maxLength: 5000)),
      FieldLabel(
        'Ангилал',
        child: DropdownButtonFormField<String?>(
          initialValue: catIds.contains(_categoryId) ? _categoryId : null,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: [
            const DropdownMenuItem<String?>(
                value: null, child: Text('Ангилалгүй')),
            for (final c in cats.where((c) => c.active || c.id == _categoryId))
              DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
      ),
      FieldLabel('Зургууд (холбоос)',
          hint: 'Хамгийн ихдээ 10',
          child: Column(children: [
            for (var i = 0; i < _images.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _images[i],
                      decoration: const InputDecoration(hintText: 'https://…'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () =>
                        setState(() => _images.removeAt(i).dispose()),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: AdminButton('Зураг нэмэх',
                  icon: LucideIcons.plus,
                  onPressed: _images.length >= 10
                      ? null
                      : () =>
                          setState(() => _images.add(TextEditingController()))),
            ),
          ])),
      _two(
        FieldLabel('Эхлэх үнэ (₮)',
            child: TextField(
                controller: _price, keyboardType: TextInputType.number)),
        FieldLabel('Үнийн алхам (₮)',
            child: TextField(
                controller: _inc, keyboardType: TextInputType.number)),
      ),
      const Divider(),
      const SizedBox(height: 14),
      FieldLabel(
        'Хуваарь',
        child: Align(
          alignment: Alignment.centerLeft,
          child: AdminSegments<bool>(
            options: const [(false, 'Нэг хугацаа'), (true, 'Раундтай')],
            value: _useRounds,
            // Засахдаа горим солихгүй: backend раундыг арилгаж чадахгүй.
            onChanged: (v) => _editing ? null : setState(() => _useRounds = v),
          ),
        ),
      ),
      if (!_useRounds) ...[
        _two(
          FieldLabel('Эхлэх цаг',
              child: DateTimeField(
                  value: _start, onChanged: (d) => setState(() => _start = d))),
          FieldLabel('Дуусах цаг',
              child: DateTimeField(
                  value: _end, onChanged: (d) => setState(() => _end = d))),
        ),
        _two(
          FieldLabel('Сунгалтын цонх (сек)',
              hint: 'Дуусахад энэ хугацаанд санал орвол сунгана',
              child: TextField(
                  controller: _soft, keyboardType: TextInputType.number)),
          FieldLabel('Сунгах хугацаа (сек)',
              child: TextField(
                  controller: _extend, keyboardType: TextInputType.number)),
        ),
      ] else ...[
        Row(children: [
          AdminButton('Загвар ашиглах',
              icon: LucideIcons.wand, onPressed: _useTemplate),
          const SizedBox(width: 8),
          AdminButton('Раунд нэмэх', icon: LucideIcons.plus, onPressed: () {
            setState(() {
              final last = _rounds.isEmpty ? null : _rounds.last.end;
              _rounds
                  .add(_Round(last, last?.add(const Duration(hours: 1)), 60));
            });
          }),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < _rounds.length; i++) _roundRow(i),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(_error!,
              style: const TextStyle(fontSize: 13, color: AdminColors.red)),
        ),
      const SizedBox(height: 10),
      Row(children: [
        AdminButton(_editing ? 'Хадгалах' : 'Ноорог үүсгэх',
            kind: BtnKind.primary, busy: _busy, onPressed: _save),
        const SizedBox(width: 8),
        AdminButton('Болих', onPressed: () => Navigator.pop(context)),
      ]),
    ]);
  }

  Widget _roundRow(int i) {
    final r = _rounds[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(children: [
        Row(children: [
          Text('Раунд ${i + 1}',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(LucideIcons.trash2,
                size: 15, color: AdminColors.red),
            onPressed: () => setState(() => _rounds.removeAt(i).dur.dispose()),
          ),
        ]),
        _two(
          FieldLabel('Эхлэх',
              child: DateTimeField(
                  value: r.start,
                  onChanged: (d) => setState(() => r.start = d))),
          FieldLabel('Дуусах',
              child: DateTimeField(
                  value: r.end, onChanged: (d) => setState(() => r.end = d))),
        ),
        FieldLabel('Тоолуурын урт (сек)',
            child: TextField(
                controller: r.dur, keyboardType: TextInputType.number)),
      ]),
    );
  }
}
