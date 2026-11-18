import 'package:intl/intl.dart';

import '../../core/models.dart';

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

/// Яг огноо+цаг (local): "2026.11.18 14:00".
String formatExactDateTime(DateTime t) =>
    DateFormat('yyyy.MM.dd HH:mm').format(t.toLocal());

/// Саналын илгээсэн яг цаг (local): өнөөдөр "HH:mm:ss", бусад өдөр "MM.dd HH:mm:ss".
String formatBidTime(DateTime t, DateTime now) {
  final s = t.toLocal();
  final n = now.toLocal();
  final sameDay = s.year == n.year && s.month == n.month && s.day == n.day;
  return DateFormat(sameDay ? 'HH:mm:ss' : 'MM.dd HH:mm:ss').format(s);
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

/// `t` цагт хамаарах шатны индекс: startsAt <= t < endsAt. Эхний шатнаас өмнө
/// бол эхний шат; завсар/сүүлийн шатнаас хойш бол startsAt <= t байх сүүлийн шат.
int? roundIndexAt(List<AuctionRound> rounds, DateTime t) {
  if (rounds.isEmpty) return null;
  if (t.isBefore(rounds.first.startsAt)) return 0;
  var idx = 0;
  for (var i = 0; i < rounds.length; i++) {
    if (!rounds[i].startsAt.isAfter(t)) idx = i;
  }
  return idx;
}

/// Шатны урт: "1 цаг", "1 цаг 30 мин", "45 мин", "1 мин 30 сек", "30 сек".
String formatRoundDuration(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) return m > 0 ? '$h цаг $m мин' : '$h цаг';
  if (m > 0) return s > 0 ? '$m мин $s сек' : '$m мин';
  return '$s сек';
}

/// "10:10–13:10" (local цаг, en dash).
String formatTimeRange(DateTime a, DateTime b) {
  final f = DateFormat('HH:mm');
  return '${f.format(a.toLocal())}–${f.format(b.toLocal())}';
}
