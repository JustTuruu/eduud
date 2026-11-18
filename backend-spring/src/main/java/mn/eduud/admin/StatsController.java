package mn.eduud.admin;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import io.micrometer.core.instrument.distribution.ValueAtPercentile;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.AuthAnnotations.Roles;
import mn.eduud.config.AppProperties;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Админ хяналтын самбарын нэгтгэсэн статистик. "Өнөөдөр" нь Asia/Ulaanbaatar цагаар. */
@Roles("admin")
@RestController
@RequestMapping("/admin")
public class StatsController {
  private static final ZoneId ZONE = ZoneId.of("Asia/Ulaanbaatar");

  private final JdbcClient db;
  private final Rows rows;
  private final MeterRegistry meters;
  private final AppProperties props;

  public StatsController(JdbcClient db, Rows rows, MeterRegistry meters, AppProperties props) {
    this.db = db;
    this.rows = rows;
    this.meters = meters;
    this.props = props;
  }

  @GetMapping("/stats")
  public Map<String, Object> stats(@RequestParam(defaultValue = "14") int days) {
    int d = Math.max(7, Math.min(90, days));
    Instant now = Instant.now();
    LocalDate today = now.atZone(ZONE).toLocalDate();
    Instant todayStart = today.atStartOfDay(ZONE).toInstant();
    Instant periodStart = today.minusDays(d - 1L).atStartOfDay(ZONE).toInstant();
    Instant ago24h = now.minus(24, ChronoUnit.HOURS);
    Instant ago7d = now.minus(7, ChronoUnit.DAYS);

    Map<String, Object> out = new LinkedHashMap<>();
    out.put("users", users(todayStart, ago7d));
    out.put("auctions", auctions(todayStart));
    out.put("bids", bids(todayStart, ago24h, now));
    out.put("revenue", revenue(periodStart, today, d));
    out.put("tokens", tokens(todayStart, periodStart));
    out.put("orders", orders());
    out.put("requests", requests());
    out.put("feedback", Map.of("open", count("SELECT count(*) FROM feedback WHERE status = 'open'")));
    out.put("pipeline", pipeline());
    out.put("topAuctions", topAuctions(ago24h));
    return out;
  }

  private Map<String, Object> users(Instant todayStart, Instant ago7d) {
    return db.sql(
            "SELECT count(*) AS total,"
                + " count(*) FILTER (WHERE created_at >= ?) AS new_today,"
                + " count(*) FILTER (WHERE created_at >= ?) AS new7d,"
                + " count(*) FILTER (WHERE status = 'banned') AS banned FROM users")
        .params(Rows.ts(todayStart), Rows.ts(ago7d))
        .query(rows.camel())
        .single();
  }

  private Map<String, Object> auctions(Instant todayStart) {
    return db.sql(
            "SELECT count(*) FILTER (WHERE status = 'live') AS live,"
                + " count(*) FILTER (WHERE status = 'scheduled') AS scheduled,"
                + " count(*) FILTER (WHERE status = 'draft') AS draft,"
                + " count(*) FILTER (WHERE status IN ('ended', 'settled') AND ends_at >= ? AND ends_at <= now()) AS ended_today,"
                + " count(*) AS total FROM auctions")
        .param(Rows.ts(todayStart))
        .query(rows.camel())
        .single();
  }

  private Map<String, Object> bids(Instant todayStart, Instant ago24h, Instant now) {
    Map<String, Object> out =
        new LinkedHashMap<>(
            db.sql(
                    "SELECT count(*) FILTER (WHERE created_at >= ?) AS today,"
                        + " count(*) FILTER (WHERE created_at >= ?) AS last24h, count(*) AS total FROM bids")
                .params(Rows.ts(todayStart), Rows.ts(ago24h))
                .query(rows.camel())
                .single());
    // 24 цагийн bucket: одоогийн цагийг оролцуулан 23 цагийн өмнөөс
    Instant firstHour = now.truncatedTo(ChronoUnit.HOURS).minus(23, ChronoUnit.HOURS);
    Map<Instant, Long> counts = new HashMap<>();
    db.sql(
            "SELECT date_trunc('hour', created_at) AS hour, count(*) AS cnt FROM bids"
                + " WHERE created_at >= ? GROUP BY 1")
        .param(Rows.ts(firstHour))
        .query(
            (rs, i) -> {
              counts.put(rs.getObject("hour", LocalDateTime.class).toInstant(ZoneOffset.UTC), rs.getLong("cnt"));
              return 0;
            })
        .list();
    out.put("perHour", StatsBuckets.fillHours(counts, now, 24));
    return out;
  }

  private Map<String, Object> revenue(Instant periodStart, LocalDate today, int days) {
    Map<LocalDate, Long> topup = new HashMap<>();
    Map<LocalDate, Long> order = new HashMap<>();
    // paid_at нь UTC naive timestamp -> Улаанбаатарын өдөр
    db.sql(
            "SELECT ((paid_at AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ulaanbaatar')::date AS day,"
                + " kind::text AS kind, sum(amount_mnt) AS total FROM payments"
                + " WHERE status = 'paid' AND paid_at >= ? GROUP BY 1, 2")
        .param(Rows.ts(periodStart))
        .query(
            (rs, i) -> {
              LocalDate day = rs.getDate("day").toLocalDate();
              ("topup".equals(rs.getString("kind")) ? topup : order).put(day, rs.getLong("total"));
              return 0;
            })
        .list();
    long todayMnt = topup.getOrDefault(today, 0L) + order.getOrDefault(today, 0L);
    long periodMnt = topup.values().stream().mapToLong(Long::longValue).sum()
        + order.values().stream().mapToLong(Long::longValue).sum();
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("todayMnt", todayMnt);
    out.put("periodMnt", periodMnt);
    out.put("perDay", StatsBuckets.fillDays(topup, order, today, days));
    return out;
  }

  private Map<String, Object> tokens(Instant todayStart, Instant periodStart) {
    Map<String, Object> out =
        new LinkedHashMap<>(
            db.sql(
                    "SELECT coalesce(sum(amount) FILTER (WHERE type = 'purchase' AND created_at >= ?), 0) AS sold_today,"
                        + " coalesce(sum(amount) FILTER (WHERE type = 'purchase' AND created_at >= ?), 0) AS sold_period,"
                        + " coalesce(-sum(amount) FILTER (WHERE type = 'bid' AND created_at >= ?), 0) AS spent_today"
                        + " FROM token_transactions WHERE created_at >= ?")
                .params(Rows.ts(todayStart), Rows.ts(periodStart), Rows.ts(todayStart), Rows.ts(periodStart))
                .query(rows.camel())
                .single());
    out.put("inCirculation", db.sql("SELECT coalesce(sum(balance), 0) FROM wallets").query(Long.class).single());
    return out;
  }

  private Map<String, Object> orders() {
    return db.sql(
            "SELECT count(*) FILTER (WHERE status = 'pending') AS pending_payment,"
                + " count(*) FILTER (WHERE status = 'paid') AS paid,"
                + " count(*) FILTER (WHERE status = 'paid' AND coalesce(delivery_info->>'status', '') <> 'delivered') AS to_deliver,"
                + " count(*) FILTER (WHERE status = 'expired') AS expired FROM orders")
        .query(rows.camel())
        .single();
  }

  private Map<String, Object> requests() {
    return db.sql(
            "SELECT count(*) FILTER (WHERE status = 'pending') AS pending,"
                + " count(*) FILTER (WHERE status = 'reviewing') AS reviewing,"
                + " count(*) FILTER (WHERE status = 'info_requested') AS info_requested FROM auction_requests")
        .query(rows.camel())
        .single();
  }

  private Map<String, Object> pipeline() {
    Map<String, Object> out = new LinkedHashMap<>();
    out.put("mode", props.bid().isKafka() ? "kafka" : "direct");
    out.put("accepted", counter("accepted"));
    out.put("rejected", counter("rejected"));
    out.put("duplicate", counter("duplicate"));
    Double avg = null;
    Double p95 = null;
    Timer timer = meters.find("bids.end_to_end").timer();
    if (timer != null && timer.count() > 0) {
      avg = round1(timer.mean(TimeUnit.MILLISECONDS));
      for (ValueAtPercentile v : timer.takeSnapshot().percentileValues()) {
        if (Math.abs(v.percentile() - 0.95) < 1e-9) p95 = round1(v.value(TimeUnit.MILLISECONDS));
      }
    }
    out.put("avgEndToEndMs", avg);
    out.put("p95EndToEndMs", p95);
    return out;
  }

  private long counter(String result) {
    var c = meters.find("bids.processed").tag("result", result).counter();
    return c == null ? 0L : (long) c.count();
  }

  private static double round1(double v) {
    return Math.round(v * 10.0) / 10.0;
  }

  private List<Map<String, Object>> topAuctions(Instant ago24h) {
    return db.sql(
            "SELECT a.id, a.title, a.status, a.bid_count, a.current_price, t.cnt AS bids_last24h"
                + " FROM (SELECT auction_id, count(*) AS cnt FROM bids WHERE created_at >= ?"
                + "       GROUP BY auction_id ORDER BY cnt DESC LIMIT 5) t"
                + " JOIN auctions a ON a.id = t.auction_id ORDER BY t.cnt DESC")
        .param(Rows.ts(ago24h))
        .query(rows.camel())
        .list();
  }

  private long count(String sql) {
    return db.sql(sql).query(Long.class).single();
  }
}
