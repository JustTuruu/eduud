import 'package:intl/intl.dart';

/// Дуудлага худалдааны хугацааны цэвэр (UI-аас хараат бус) туслахууд.

/// Үлдсэн хугацааны хувь (0..1) — нийт хугацаа startsAt→endsAt-д харьцуулсан.
/// Хугацаа дууссан бол 0, эхлээгүй бол 1; нийт хугацаа 0 бол 0.
double remainingFraction({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final total = endsAt.difference(startsAt).inMilliseconds;
  if (total <= 0) return 0;
  final left = endsAt.difference(now).inMilliseconds;
  return (left / total).clamp(0.0, 1.0);
}

/// Үлдсэн хугацааг `mm:ss`, нэг цагаас дээш бол `h:mm:ss` болгоно.
/// Сөрөг утгыг 00:00 гэж үзнэ.
String formatRemaining(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Эхлэх цагийн шошго: "Өнөөдөр 20:00", "Маргааш 20:00", бусад үед
/// "11-р сарын 20 · 20:00".
String formatStartLabel(DateTime start, DateTime now) {
  final s = start.toLocal();
  final n = now.toLocal();
  final time = DateFormat('HH:mm').format(s);
  final dayDiff = DateTime(s.year, s.month, s.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (dayDiff == 0) return 'Өнөөдөр $time';
  if (dayDiff == 1) return 'Маргааш $time';
  return '${s.month}-р сарын ${s.day} · $time';
}
