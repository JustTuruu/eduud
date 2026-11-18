import 'dart:async';

import 'package:dio/dio.dart' show Options;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';

typedef Json = Map<String, dynamic>;

// ---------- Аюулгүй задлагч ----------

int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
double? _dn(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
Json _m(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Json> _l(dynamic v) => v is List ? [for (final e in v) _m(e)] : <Json>[];

/// Json-оос тоо авна (null бол 0).
int jInt(Json m, String k) => _i(m[k]);

/// Дотоод объектыг (жиш. wallet) авна.
Json jMap(Json m, String k) => _m(m[k]);

/// Json-оос текст авна (null бол '').
String jStr(Json m, String k) => (m[k] ?? '').toString();

// ---------- Статистик ----------

class HourCount {
  const HourCount(this.hour, this.count);
  final int hour;
  final int count;
}

class DayRevenue {
  const DayRevenue(this.date, this.topupMnt, this.orderMnt);
  final String date;
  final int topupMnt;
  final int orderMnt;
}

class TopAuction {
  const TopAuction({
    required this.id,
    required this.title,
    required this.status,
    required this.bidCount,
    required this.currentPrice,
    required this.bidsLast24h,
  });
  final String id, title, status;
  final int bidCount, currentPrice, bidsLast24h;
}

class Pipeline {
  const Pipeline({
    required this.mode,
    required this.accepted,
    required this.rejected,
    required this.duplicate,
    this.avgMs,
    this.p95Ms,
  });
  final String mode;
  final int accepted, rejected, duplicate;
  final double? avgMs, p95Ms;
  int get total => accepted + rejected + duplicate;
}

class AdminStats {
  const AdminStats({
    required this.usersTotal,
    required this.usersNewToday,
    required this.usersNew7d,
    required this.usersBanned,
    required this.auctionsLive,
    required this.auctionsScheduled,
    required this.auctionsDraft,
    required this.auctionsEndedToday,
    required this.auctionsTotal,
    required this.bidsToday,
    required this.bidsLast24h,
    required this.bidsTotal,
    required this.bidsPerHour,
    required this.revenueToday,
    required this.revenuePeriod,
    required this.revenuePerDay,
    required this.tokensSoldToday,
    required this.tokensSoldPeriod,
    required this.tokensSpentToday,
    required this.tokensInCirculation,
    required this.ordersPendingPayment,
    required this.ordersPaid,
    required this.ordersToDeliver,
    required this.ordersExpired,
    required this.reqPending,
    required this.reqReviewing,
    required this.reqInfoRequested,
    required this.feedbackOpen,
    required this.pipeline,
    required this.topAuctions,
  });

  final int usersTotal, usersNewToday, usersNew7d, usersBanned;
  final int auctionsLive,
      auctionsScheduled,
      auctionsDraft,
      auctionsEndedToday,
      auctionsTotal;
  final int bidsToday, bidsLast24h, bidsTotal;
  final List<HourCount> bidsPerHour;
  final int revenueToday, revenuePeriod;
  final List<DayRevenue> revenuePerDay;
  final int tokensSoldToday,
      tokensSoldPeriod,
      tokensSpentToday,
      tokensInCirculation;
  final int ordersPendingPayment, ordersPaid, ordersToDeliver, ordersExpired;
  final int reqPending, reqReviewing, reqInfoRequested;
  final int feedbackOpen;
  final Pipeline pipeline;
  final List<TopAuction> topAuctions;

  /// Шалгах шаардлагатай нийт хүсэлт.
  int get requestsOpen => reqPending + reqReviewing + reqInfoRequested;

  /// Хоосон мэдээлэлд (талбар дутуу) ч унахгүй задална.
  factory AdminStats.fromJson(Json j) {
    final u = _m(j['users']);
    final a = _m(j['auctions']);
    final b = _m(j['bids']);
    final r = _m(j['revenue']);
    final t = _m(j['tokens']);
    final o = _m(j['orders']);
    final q = _m(j['requests']);
    final p = _m(j['pipeline']);
    return AdminStats(
      usersTotal: _i(u['total']),
      usersNewToday: _i(u['newToday']),
      usersNew7d: _i(u['new7d']),
      usersBanned: _i(u['banned']),
      auctionsLive: _i(a['live']),
      auctionsScheduled: _i(a['scheduled']),
      auctionsDraft: _i(a['draft']),
      auctionsEndedToday: _i(a['endedToday']),
      auctionsTotal: _i(a['total']),
      bidsToday: _i(b['today']),
      bidsLast24h: _i(b['last24h']),
      bidsTotal: _i(b['total']),
      bidsPerHour: [
        for (final h in _l(b['perHour']))
          HourCount(_hourOf(h['hour']), _i(h['count'])),
      ],
      revenueToday: _i(r['todayMnt']),
      revenuePeriod: _i(r['periodMnt']),
      revenuePerDay: [
        for (final d in _l(r['perDay']))
          DayRevenue(jStr(d, 'date'), _i(d['topupMnt']), _i(d['orderMnt'])),
      ],
      tokensSoldToday: _i(t['soldToday']),
      tokensSoldPeriod: _i(t['soldPeriod']),
      tokensSpentToday: _i(t['spentToday']),
      tokensInCirculation: _i(t['inCirculation']),
      ordersPendingPayment: _i(o['pendingPayment']),
      ordersPaid: _i(o['paid']),
      ordersToDeliver: _i(o['toDeliver']),
      ordersExpired: _i(o['expired']),
      reqPending: _i(q['pending']),
      reqReviewing: _i(q['reviewing']),
      reqInfoRequested: _i(q['infoRequested']),
      feedbackOpen: _i(_m(j['feedback'])['open']),
      pipeline: Pipeline(
        mode: jStr(p, 'mode').isEmpty ? '—' : jStr(p, 'mode'),
        accepted: _i(p['accepted']),
        rejected: _i(p['rejected']),
        duplicate: _i(p['duplicate']),
        avgMs: _dn(p['avgEndToEndMs']),
        p95Ms: _dn(p['p95EndToEndMs']),
      ),
      topAuctions: [
        for (final x in _l(j['topAuctions']))
          TopAuction(
            id: jStr(x, 'id'),
            title: jStr(x, 'title'),
            status: jStr(x, 'status'),
            bidCount: _i(x['bidCount']),
            currentPrice: _i(x['currentPrice']),
            bidsLast24h: _i(x['bidsLast24h']),
          ),
      ],
    );
  }
}

/// `hour` нь 0-23 тоо эсвэл ISO цаг байж болно.
int _hourOf(dynamic v) {
  if (v is num) return v.toInt();
  final d = DateTime.tryParse('$v');
  return d?.toLocal().hour ?? 0;
}

// ---------- Ангилал ----------

class AdminCategory {
  const AdminCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.active,
    required this.auctionCount,
  });
  final String id, name;
  final int sortOrder, auctionCount;
  final bool active;

  factory AdminCategory.fromJson(Json j) => AdminCategory(
        id: jStr(j, 'id'),
        name: jStr(j, 'name'),
        sortOrder: _i(j['sortOrder']),
        active: j['active'] != false,
        auctionCount: _i(j['auctionCount']),
      );
}

// ---------- Providers ----------

/// Хянах самбарын хугацааны сонголт (өдөр).
final adminDaysProvider = StateProvider<int>((ref) => 14);

/// Статистик — 30 секунд тутам автоматаар шинэчлэгдэнэ.
final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) async {
  final days = ref.watch(adminDaysProvider);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final res = await ref
      .watch(dioProvider)
      .get('/admin/stats', queryParameters: {'days': days});
  return AdminStats.fromJson(_m(res.data));
});

Future<List<Json>> _getList(
  Ref ref,
  String path, [
  Map<String, dynamic>? query,
]) async {
  final res = await ref.watch(dioProvider).get(path, queryParameters: query);
  return _l(res.data);
}

final adminCategoriesProvider =
    FutureProvider.autoDispose<List<AdminCategory>>((ref) async {
  final rows = await _getList(ref, '/admin/categories');
  return rows.map(AdminCategory.fromJson).toList();
});

/// Дуудлагын жагсаалт; параметр нь төлөв ('' = бүгд).
final adminAuctionsProvider = FutureProvider.autoDispose
    .family<List<Json>, String>((ref, status) => _getList(
        ref, '/admin/auctions', status.isEmpty ? null : {'status': status}));

final adminRequestsProvider = FutureProvider.autoDispose
    .family<List<Json>, String>((ref, status) => _getList(ref,
        '/admin/auction-requests', status.isEmpty ? null : {'status': status}));

final adminUsersProvider = FutureProvider.autoDispose
    .family<List<Json>, String>(
        (ref, q) => _getList(ref, '/admin/users', q.isEmpty ? null : {'q': q}));

final adminOrdersProvider = FutureProvider.autoDispose<List<Json>>(
    (ref) => _getList(ref, '/admin/orders'));

final adminPaymentsProvider = FutureProvider.autoDispose<List<Json>>(
    (ref) => _getList(ref, '/admin/payments'));

final adminFeedbackProvider = FutureProvider.autoDispose
    .family<List<Json>, String>((ref, status) => _getList(
        ref, '/feedback/admin', status.isEmpty ? null : {'status': status}));

// ---------- Үйлдлүүд ----------

/// Бичих (POST/PATCH/DELETE) хүсэлтүүд. Алдааг дуудсан газар барьж
/// `apiErrorMessage`-ээр харуулна.
class AdminApi {
  AdminApi(this.ref);
  final Ref ref;

  Future<Json> _send(String method, String path, [Object? data]) async {
    final res = await ref.read(dioProvider).request(
          path,
          data: data,
          options: Options(method: method),
        );
    return _m(res.data);
  }

  Future<Json> createAuction(Json body) =>
      _send('POST', '/admin/auctions', body);
  Future<Json> updateAuction(String id, Json body) =>
      _send('PATCH', '/admin/auctions/$id', body);
  Future<Json> publishAuction(String id) =>
      _send('POST', '/admin/auctions/$id/publish');
  Future<Json> cancelAuction(String id) =>
      _send('POST', '/admin/auctions/$id/cancel');

  Future<Json> decideRequest(String id, String status, String note) => _send(
      'POST',
      '/admin/auction-requests/$id/decision',
      {'status': status, 'note': note.isEmpty ? null : note});

  Future<Json> createCategory(String name, int sortOrder) => _send(
      'POST', '/admin/categories', {'name': name, 'sortOrder': sortOrder});
  Future<Json> updateCategory(String id, Json body) =>
      _send('PATCH', '/admin/categories/$id', body);
  Future<Json> deleteCategory(String id) =>
      _send('DELETE', '/admin/categories/$id');

  Future<Json> banUser(String id, bool ban) =>
      _send('POST', '/admin/users/$id/${ban ? 'ban' : 'unban'}');
  Future<Json> adjustTokens(String id, int amount, String note) => _send('POST',
      '/admin/users/$id/adjust-tokens', {'amount': amount, 'note': note});

  Future<Json> updateDelivery(String orderId, Json info) =>
      _send('PATCH', '/admin/orders/$orderId/delivery', info);

  Future<Json> updateFeedback(String id, String status, String note) => _send(
      'PATCH', '/feedback/admin/$id', {'status': status, 'adminNote': note});
}

final adminApiProvider = Provider<AdminApi>((ref) => AdminApi(ref));
