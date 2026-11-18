package mn.eduud.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Map;
import org.junit.jupiter.api.Test;

class StatsBucketsTest {
  @Test
  void hoursAre24ZeroFilledOldestFirst() {
    Instant now = Instant.parse("2026-01-10T12:34:56Z");
    var out = StatsBuckets.fillHours(Map.of(Instant.parse("2026-01-10T12:00:00Z"), 5L), now, 24);
    assertThat(out).hasSize(24);
    assertThat(out.get(0).get("hour")).isEqualTo("2026-01-09T13:00:00Z");
    assertThat(out.get(0).get("count")).isEqualTo(0L);
    assertThat(out.get(23).get("hour")).isEqualTo("2026-01-10T12:00:00Z");
    assertThat(out.get(23).get("count")).isEqualTo(5L);
  }

  @Test
  void daysZeroFilledOldestFirst() {
    LocalDate last = LocalDate.parse("2026-01-10");
    var out = StatsBuckets.fillDays(Map.of(last, 100L), Map.of(last.minusDays(1), 7L), last, 7);
    assertThat(out).hasSize(7);
    assertThat(out.get(0).get("date")).isEqualTo("2026-01-04");
    assertThat(out.get(5).get("orderMnt")).isEqualTo(7L);
    assertThat(out.get(6).get("topupMnt")).isEqualTo(100L);
    assertThat(out.get(6).get("orderMnt")).isEqualTo(0L);
  }
}
