import 'package:intl/intl.dart';

/// Дуудлага худалдааны хугацааны цэвэр (UI-аас хараат бус) туслахууд.

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

/// Огноо+цагийн шошго: "Өчигдөр 14:00", "Өнөөдөр 14:00", "Маргааш 14:00", бусад
/// үед "11-р сарын 20 · 14:00". Бүгдийг local цагаар.
String formatDateTimeLabel(DateTime t, DateTime now) {
  final s = t.toLocal();
  final n = now.toLocal();
  final time = DateFormat('HH:mm').format(s);
  final dayDiff = DateTime(s.year, s.month, s.day)
      .difference(DateTime(n.year, n.month, n.day))
      .inDays;
  if (dayDiff == 0) return 'Өнөөдөр $time';
  if (dayDiff == 1) return 'Маргааш $time';
  if (dayDiff == -1) return 'Өчигдөр $time';
  return '${s.month}-р сарын ${s.day} · $time';
}

/// Эхлэх цагийн шошго: "Өнөөдөр 20:00", "Маргааш 20:00", бусад үед
/// "11-р сарын 20 · 20:00".
String formatStartLabel(DateTime start, DateTime now) =>
    formatDateTimeLabel(start, now);

/// Сунгалтын шат: үлдсэн хугацаа > 0 бөгөөд softCloseSec-ээс бага.
/// softCloseSec <= 0 (мэдээлэл байхгүй) бол хэзээ ч сунгалтын шат биш.
bool inSoftClose(Duration remaining, int softCloseSec) =>
    softCloseSec > 0 &&
    remaining.inMilliseconds > 0 &&
    remaining.inMilliseconds < softCloseSec * 1000;
