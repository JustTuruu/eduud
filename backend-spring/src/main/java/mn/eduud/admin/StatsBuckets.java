package mn.eduud.admin;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Статистикийн цагийн/өдрийн bucket-ыг тэгээр бөглөх цэвэр туслахууд. */
public final class StatsBuckets {
  private StatsBuckets() {}

  /** `endHour`-оор төгсөх яг `hours` ширхэг цагийн bucket (хуучнаас шинэ рүү), дутууг 0-ээр. */
  public static List<Map<String, Object>> fillHours(Map<Instant, Long> counts, Instant endHour, int hours) {
    List<Map<String, Object>> out = new ArrayList<>(hours);
    Instant start = endHour.truncatedTo(ChronoUnit.HOURS).minus(hours - 1L, ChronoUnit.HOURS);
    for (int i = 0; i < hours; i++) {
      Instant h = start.plus(i, ChronoUnit.HOURS);
      Map<String, Object> m = new LinkedHashMap<>();
      m.put("hour", h.toString());
      m.put("count", counts.getOrDefault(h, 0L));
      out.add(m);
    }
    return out;
  }

  /** `lastDay`-ээр төгсөх `days` өдөр; topup/order дүнг өдрөөр, дутууг 0-ээр бөглөнө. */
  public static List<Map<String, Object>> fillDays(
      Map<LocalDate, Long> topup, Map<LocalDate, Long> order, LocalDate lastDay, int days) {
    List<Map<String, Object>> out = new ArrayList<>(days);
    for (int i = days - 1; i >= 0; i--) {
      LocalDate d = lastDay.minusDays(i);
      Map<String, Object> m = new LinkedHashMap<>();
      m.put("date", d.toString());
      m.put("topupMnt", topup.getOrDefault(d, 0L));
      m.put("orderMnt", order.getOrDefault(d, 0L));
      out.add(m);
    }
    return out;
  }
}
