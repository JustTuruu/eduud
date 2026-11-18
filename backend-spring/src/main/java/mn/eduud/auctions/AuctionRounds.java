package mn.eduud.auctions;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import mn.eduud.common.ApiException;

/**
 * Дуудлага худалдааны раундын (раунд) хуваарь — DB-ээс хараат бус цэвэр логик.
 * Эхний саналаас хойш тоолуур ажиллаж, санал бүрд тухайн агшны раундын хугацаагаар шинээр эхэлнэ.
 */
public final class AuctionRounds {
  private static final ObjectMapper MAPPER = new ObjectMapper();
  public static final int MAX_ROUNDS = 50;
  public static final int MAX_DURATION_SEC = 86400;

  private AuctionRounds() {}

  /** Нэг раунд: [startsAt, endsAt) цонх, түүнд ирсэн санал бүрийн дараах тоолуурын хугацаа. */
  public record Round(Instant startsAt, Instant endsAt, int durationSec) {}

  /** t агшинд хамаарах раунд: цонхонд багтвал тэр, эхнээс өмнө бол эхний, завсар/төгсгөлийн дараа бол сүүлийн эхэлсэн раунд. */
  public static Round roundAt(List<Round> rounds, Instant t) {
    if (rounds == null || rounds.isEmpty()) return null;
    Round current = rounds.get(0);
    for (Round r : rounds) {
      if (r.startsAt().isAfter(t)) break;
      current = r;
    }
    return current;
  }

  /** `rounds::text` JSON-г задлана. null/хоосон бол null. */
  public static List<Round> parse(String json) {
    if (json == null || json.isBlank()) return null;
    try {
      JsonNode root = MAPPER.readTree(json);
      if (root == null || !root.isArray() || root.isEmpty()) return null;
      List<Round> out = new ArrayList<>();
      for (JsonNode n : root) {
        out.add(
            new Round(
                Instant.parse(n.get("startsAt").asText()),
                Instant.parse(n.get("endsAt").asText()),
                n.get("durationSec").asInt()));
      }
      return out;
    } catch (Exception e) {
      throw new IllegalStateException("Раундын JSON буруу байна", e);
    }
  }

  /** DB-д хадгалах JSON. */
  public static String toJson(List<Round> rounds) {
    try {
      List<java.util.Map<String, Object>> list = new ArrayList<>();
      for (Round r : rounds) {
        java.util.Map<String, Object> m = new java.util.LinkedHashMap<>();
        m.put("startsAt", r.startsAt().toString());
        m.put("endsAt", r.endsAt().toString());
        m.put("durationSec", r.durationSec());
        list.add(m);
      }
      return MAPPER.writeValueAsString(list);
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /** Хуваарийг шалгана: 1..50 раунд, durationSec 1..86400, startsAt < endsAt, өсөх дараалал, давхцалгүй. */
  public static void validate(List<Round> rounds) {
    if (rounds == null || rounds.isEmpty() || rounds.size() > MAX_ROUNDS) {
      throw ApiException.badRequest("Раундын тоо 1-ээс " + MAX_ROUNDS + " хооронд байх ёстой.");
    }
    Instant prevEnd = null;
    for (int i = 0; i < rounds.size(); i++) {
      Round r = rounds.get(i);
      String n = "Раунд " + (i + 1) + ": ";
      if (r == null || r.startsAt() == null || r.endsAt() == null) {
        throw ApiException.badRequest(n + "эхлэх болон дуусах хугацаа заавал байх ёстой.");
      }
      if (r.durationSec() < 1 || r.durationSec() > MAX_DURATION_SEC) {
        throw ApiException.badRequest(n + "хугацаа 1-ээс " + MAX_DURATION_SEC + " секунд байх ёстой.");
      }
      if (!r.startsAt().isBefore(r.endsAt())) {
        throw ApiException.badRequest(n + "дуусах хугацаа эхлэхээс хойш байх ёстой.");
      }
      if (prevEnd != null && r.startsAt().isBefore(prevEnd)) {
        throw ApiException.badRequest(n + "өмнөх раундтай давхцаж болохгүй, өсөх дарааллаар байх ёстой.");
      }
      prevEnd = r.endsAt();
    }
  }

  /** Анхдагч хуваарь: R1 3ц (1ц), R2..R8 1ц цонх (45м,30м,20м,10м,5м,3м,1м), R9..R11 40м цонх (30с,10с,5с). */
  public static List<Round> defaultSchedule(Instant start) {
    List<Round> out = new ArrayList<>();
    Instant t = start;
    Instant end = t.plusSeconds(3 * 3600);
    out.add(new Round(t, end, 3600));
    t = end;
    int[] mid = {2700, 1800, 1200, 600, 300, 180, 60};
    for (int d : mid) {
      end = t.plusSeconds(3600);
      out.add(new Round(t, end, d));
      t = end;
    }
    int[] last = {30, 10, 5};
    for (int d : last) {
      end = t.plusSeconds(40 * 60);
      out.add(new Round(t, end, d));
      t = end;
    }
    return out;
  }
}
