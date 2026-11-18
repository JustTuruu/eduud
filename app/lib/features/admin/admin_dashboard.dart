import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'admin_api.dart';
import 'admin_theme.dart';
import 'admin_widgets.dart';

/// Хянах самбар: үзүүлэлтүүд, график, Kafka pipeline, топ дуудлагууд.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(adminDaysProvider);
    final stats = ref.watch(adminStatsProvider);
    return AdminPage(children: [
      AdminPageHeader(
        title: 'Хянах самбар',
        subtitle: 'Сүүлийн $days өдрийн байдал · 30 секунд тутам шинэчлэгдэнэ',
        actions: [
          AdminSegments<int>(
            options: const [
              (7, '7 өдөр'),
              (14, '14 өдөр'),
              (30, '30 өдөр'),
              (90, '90 өдөр')
            ],
            value: days,
            onChanged: (v) => ref.read(adminDaysProvider.notifier).state = v,
          ),
          AdminButton('Шинэчлэх',
              icon: LucideIcons.refreshCw,
              busy: stats.isLoading && stats.hasValue,
              onPressed: () => ref.invalidate(adminStatsProvider)),
        ],
      ),
      stats.when(
        skipLoadingOnRefresh: true,
        skipError: true,
        data: (s) => _DashboardBody(stats: s, days: days),
        loading: () => const _DashboardSkeleton(),
        error: (e, _) =>
            AdminError(e, onRetry: () => ref.invalidate(adminStatsProvider)),
      ),
    ]);
  }
}

/// Тэнцүү өргөнтэй багануудад хуваах (дэлгэцийн өргөнөөр багана тоо өөрчлөгдөнө).
class _Grid extends StatelessWidget {
  const _Grid({required this.columnsFor, required this.children});
  final int Function(double width) columnsFor;
  final List<Widget> children;
  final double gap = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = columnsFor(c.maxWidth).clamp(1, children.length);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

int _kpiCols(double w) => w >= 1100 ? 6 : (w >= 620 ? 3 : 2);
int _panelCols(double w) => w >= 1000 ? 3 : (w >= 640 ? 2 : 1);

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        _Grid(
          columnsFor: _kpiCols,
          children: [for (var i = 0; i < 6; i++) const Skeleton(height: 112)],
        ),
        const SizedBox(height: 16),
        const Skeleton(height: 300),
        const SizedBox(height: 16),
        const Skeleton(height: 220),
      ]);
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.days});
  final AdminStats stats;
  final int days;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    void go(String p) => context.go(p);
    final charts = [
      _RevenueChart(data: s.revenuePerDay, total: s.revenuePeriod, days: days),
      _BidsChart(data: s.bidsPerHour, total: s.bidsLast24h),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Grid(columnsFor: _kpiCols, children: [
        KpiCard(
          label: 'Идэвхтэй дуудлага',
          icon: LucideIcons.radio,
          value: fmtInt(s.auctionsLive),
          sub:
              '${fmtInt(s.auctionsScheduled)} товлогдсон · ${fmtInt(s.auctionsDraft)} ноорог',
          onTap: () => go('/admin/auctions'),
        ),
        KpiCard(
          label: 'Өнөөдрийн санал',
          icon: LucideIcons.hand,
          value: fmtInt(s.bidsToday),
          sub: '24 цагт ${fmtInt(s.bidsLast24h)}',
          onTap: () => go('/admin/auctions'),
        ),
        KpiCard(
          label: 'Өнөөдрийн орлого',
          icon: LucideIcons.banknote,
          value: fmtMnt(s.revenueToday),
          sub: '$days өдөрт ${fmtMnt(s.revenuePeriod)}',
          onTap: () => go('/admin/payments'),
        ),
        KpiCard(
          label: 'Шинэ хэрэглэгч',
          icon: LucideIcons.userPlus,
          value: fmtInt(s.usersNewToday),
          sub:
              '7 хоногт ${fmtInt(s.usersNew7d)} · нийт ${fmtInt(s.usersTotal)}',
          onTap: () => go('/admin/users'),
        ),
        KpiCard(
          label: 'Хүргэх захиалга',
          icon: LucideIcons.package,
          value: fmtInt(s.ordersToDeliver),
          sub: '${fmtInt(s.ordersPendingPayment)} төлбөр хүлээж буй',
          onTap: () => go('/admin/orders'),
        ),
        KpiCard(
          label: 'Хүлээгдэж буй хүсэлт',
          icon: LucideIcons.fileText,
          value: fmtInt(s.requestsOpen),
          sub:
              '${fmtInt(s.reqPending)} шинэ · ${fmtInt(s.reqInfoRequested)} мэдээлэл хүссэн',
          onTap: () => go('/admin/requests'),
        ),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: charts[0]),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: charts[1]),
          ]);
        }
        return Column(children: [
          charts[0],
          const SizedBox(height: 16),
          charts[1],
        ]);
      }),
      const SizedBox(height: 16),
      _Grid(columnsFor: _panelCols, children: [
        _PipelinePanel(p: s.pipeline),
        _TokensPanel(s: s),
        _OrdersPanel(s: s),
      ]),
      const SizedBox(height: 16),
      _TopAuctions(rows: s.topAuctions),
    ]);
  }
}

// ---------- Графикууд ----------

const _axisStyle = TextStyle(fontSize: 11, color: AdminColors.muted);

FlGridData _grid() => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          const FlLine(color: AdminColors.border, strokeWidth: 1),
    );

class _Legend extends StatelessWidget {
  const _Legend(this.items);
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 14, children: [
        for (final (c, l) in items)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(l,
                style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
          ]),
      ]);
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart(
      {required this.data, required this.total, required this.days});
  final List<DayRevenue> data;
  final int total, days;

  static const _topup = AdminColors.accent;
  static const _order = Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    final maxV =
        data.fold<int>(0, (m, d) => math.max(m, d.topupMnt + d.orderMnt));
    final maxY = maxV == 0 ? 100.0 : maxV * 1.15;
    final step = (data.length / 7).ceil().clamp(1, 100);
    return AdminCard(
      title: 'Орлого',
      subtitle: '$days өдөрт нийт ${fmtMnt(total)}',
      trailing:
          const _Legend([(_topup, 'Эрх авсан'), (_order, 'Барааны төлбөр')]),
      child: SizedBox(
        height: 260,
        child: data.isEmpty
            ? const Center(
                child: Text('Мэдээлэл алга',
                    style: TextStyle(color: AdminColors.muted)))
            : BarChart(BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: _grid(),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text(fmtCompact(v), style: _axisStyle)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length || i % step != 0) {
                          return const SizedBox.shrink();
                        }
                        final d = data[i].date;
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(d.length >= 10 ? d.substring(5) : d,
                              style: _axisStyle),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AdminColors.ink,
                    getTooltipItem: (group, _, rod, __) {
                      final d = data[group.x];
                      return BarTooltipItem(
                        '${d.date}\n',
                        const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w400),
                        children: [
                          TextSpan(
                              text: 'Эрх ${fmtMnt(d.topupMnt)}\n',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                          TextSpan(
                              text: 'Бараа ${fmtMnt(d.orderMnt)}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < data.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: (data[i].topupMnt + data[i].orderMnt).toDouble(),
                        width:
                            data.length > 40 ? 5 : (data.length > 20 ? 9 : 16),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        rodStackItems: [
                          BarChartRodStackItem(
                              0, data[i].topupMnt.toDouble(), _topup),
                          BarChartRodStackItem(
                              data[i].topupMnt.toDouble(),
                              (data[i].topupMnt + data[i].orderMnt).toDouble(),
                              _order),
                        ],
                      ),
                    ]),
                ],
              )),
      ),
    );
  }
}

class _BidsChart extends StatelessWidget {
  const _BidsChart({required this.data, required this.total});
  final List<HourCount> data;
  final int total;

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(0, (m, d) => math.max(m, d.count));
    final maxY = maxV < 4 ? 4.0 : maxV * 1.2;
    return AdminCard(
      title: 'Санал',
      subtitle: 'Сүүлийн 24 цаг · нийт ${fmtInt(total)}',
      child: SizedBox(
        height: 260,
        child: data.isEmpty
            ? const Center(
                child: Text('Мэдээлэл алга',
                    style: TextStyle(color: AdminColors.muted)))
            : LineChart(LineChartData(
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: _grid(),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, meta) => v == meta.max
                          ? const SizedBox.shrink()
                          : SideTitleWidget(
                              meta: meta,
                              child: Text(fmtCompact(v), style: _axisStyle)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= data.length || i % 6 != 0) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                              '${data[i].hour.toString().padLeft(2, '0')}:00',
                              style: _axisStyle),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AdminColors.ink,
                    getTooltipItems: (spots) => [
                      for (final sp in spots)
                        LineTooltipItem(
                          '${data[sp.x.toInt()].hour.toString().padLeft(2, '0')}:00\n',
                          const TextStyle(color: Colors.white70, fontSize: 11),
                          children: [
                            TextSpan(
                                text: '${fmtInt(sp.y)} санал',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                    ],
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < data.length; i++)
                        FlSpot(i.toDouble(), data[i].count.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    color: AdminColors.accentDark,
                    barWidth: 2.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AdminColors.accent.withValues(alpha: 0.28),
                          AdminColors.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              )),
      ),
    );
  }
}

// ---------- Самбарууд ----------

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value, {this.last = false, this.valueWidget});
  final String label, value;
  final bool last;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AdminColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AdminColors.muted)),
          ),
          valueWidget ??
              Text(value,
                  style: adminNumber(size: 14, weight: FontWeight.w600)),
        ]),
      );
}

class _PipelinePanel extends StatelessWidget {
  const _PipelinePanel({required this.p});
  final Pipeline p;

  String _ms(double? v) => v == null ? '—' : fmtInt(v);

  @override
  Widget build(BuildContext context) {
    final total = p.total;
    final isKafka = p.mode.toLowerCase() == 'kafka';
    final okPct = total == 0 ? 0.0 : p.accepted / total * 100;
    Widget seg(int n, Color c) => n <= 0
        ? const SizedBox.shrink()
        : Expanded(flex: n, child: Container(height: 8, color: c));
    return AdminCard(
      title: 'Санал боловсруулалт',
      subtitle: 'Kafka pipeline',
      trailing: StatusPill(p.mode.toUpperCase(),
          tone: isKafka ? PillTone.green : PillTone.gray),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _Metric('Дундаж', _ms(p.avgMs), 'мс')),
          Expanded(child: _Metric('p95', _ms(p.p95Ms), 'мс')),
          Expanded(
              child: _Metric(
                  'Амжилт', total == 0 ? '—' : okPct.toStringAsFixed(1), '%')),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: total == 0
              ? Container(height: 8, color: AdminColors.border)
              : Row(children: [
                  seg(p.accepted, AdminColors.accent),
                  seg(p.rejected, AdminColors.red),
                  seg(p.duplicate, AdminColors.faint),
                ]),
        ),
        const SizedBox(height: 8),
        _StatRow('Хүлээн авсан', fmtInt(p.accepted),
            valueWidget: _dotValue(AdminColors.accent, fmtInt(p.accepted))),
        _StatRow('Татгалзсан', fmtInt(p.rejected),
            valueWidget: _dotValue(AdminColors.red, fmtInt(p.rejected))),
        _StatRow('Давхардсан', fmtInt(p.duplicate),
            last: true,
            valueWidget: _dotValue(AdminColors.faint, fmtInt(p.duplicate))),
      ]),
    );
  }

  Widget _dotValue(Color c, String v) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(v, style: adminNumber(size: 14, weight: FontWeight.w600)),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.unit);
  final String label, value, unit;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: adminNumber(size: 24, weight: FontWeight.w600)
                        .copyWith(letterSpacing: -0.5)),
                const SizedBox(width: 3),
                Text(unit,
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.muted)),
              ]),
        ),
      ]);
}

class _TokensPanel extends StatelessWidget {
  const _TokensPanel({required this.s});
  final AdminStats s;

  @override
  Widget build(BuildContext context) => AdminCard(
        title: 'Эрх',
        subtitle: 'Худалдаалагдсан ба зарцуулагдсан',
        child: Column(children: [
          _StatRow('Өнөөдөр зарагдсан', fmtInt(s.tokensSoldToday)),
          _StatRow('Хугацаанд зарагдсан', fmtInt(s.tokensSoldPeriod)),
          _StatRow('Өнөөдөр зарцуулсан', fmtInt(s.tokensSpentToday)),
          _StatRow('Эргэлтэд буй', fmtInt(s.tokensInCirculation), last: true),
        ]),
      );
}

class _OrdersPanel extends StatelessWidget {
  const _OrdersPanel({required this.s});
  final AdminStats s;

  @override
  Widget build(BuildContext context) => AdminCard(
        title: 'Захиалга',
        subtitle: 'Ялагчийн төлбөр ба хүргэлт',
        child: Column(children: [
          _StatRow('Төлбөр хүлээж буй', fmtInt(s.ordersPendingPayment)),
          _StatRow('Төлсөн', fmtInt(s.ordersPaid)),
          _StatRow('Хүргэх ёстой', fmtInt(s.ordersToDeliver)),
          _StatRow('Хугацаа дууссан', fmtInt(s.ordersExpired), last: true),
        ]),
      );
}

class _TopAuctions extends StatelessWidget {
  const _TopAuctions({required this.rows});
  final List<TopAuction> rows;

  @override
  Widget build(BuildContext context) => AdminCard(
        title: 'Идэвхтэй 5 дуудлага',
        subtitle: 'Сүүлийн 24 цагийн саналаар',
        padding: const EdgeInsets.all(16),
        child: AdminTable<TopAuction>(
          rows: rows,
          empty: 'Дуудлага алга',
          onTap: (r) => context.push('/auctions/${r.id}'),
          columns: [
            AdminColumn('Нэр', (r) => cellText(r.title, bold: true), flex: 4),
            AdminColumn('Төлөв', (r) => pillFor(r.status), flex: 2),
            AdminColumn(
                '24ц санал', (r) => cellText(fmtInt(r.bidsLast24h), num: true),
                right: true),
            AdminColumn(
                'Нийт санал', (r) => cellText(fmtInt(r.bidCount), num: true),
                right: true),
            AdminColumn(
                'Үнэ', (r) => cellText(fmtMnt(r.currentPrice), num: true),
                right: true),
          ],
        ),
      );
}
