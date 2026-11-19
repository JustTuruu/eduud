package mn.eduud.auctions;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import mn.eduud.auctions.AuctionRounds.Round;

/**
 * Auction-ы цэвэр логик — DB-ээс хараат бус (NestJS-ийн auction.logic.ts-ийн хуулбар).
 */
public final class AuctionLogic {
  private AuctionLogic() {}

  /** Санал боловсруулах үеийн auction-ы төлөв. Багц дотор санах ойд шинэчлэгдэнэ. */
  public static final class Snapshot {
    public String status;
    public Instant startsAt;
    public Instant endsAt;
    public int currentPrice;
    public int increment;
    public int softCloseSec;
    public int extendSec;
    public Instant hardCloseAt;
    public String lastBidderId;
    public int bidCount;
    /** Раундын хуваарь; null бол soft-close дүрэм. */
    public List<Round> rounds;
  }

  public enum Rejection {
    NOT_LIVE("Дуудлага худалдаа идэвхгүй байна."),
    NOT_STARTED("Дуудлага худалдаа хараахан эхлээгүй байна."),
    ALREADY_ENDED("Дуудлага худалдаа дууссан байна."),
    NO_TOKENS("Token хүрэлцэхгүй байна. Дансаа цэнэглэнэ үү."),
    NOT_FOUND("Дуудлага худалдаа олдсонгүй");

    public final String message;

    Rejection(String message) {
      this.message = message;
    }
  }

  /** Санал хүлээж авах боломжтой эсэхийг шалгана. null = зөвшөөрнө. */
  public static Rejection validateBid(Snapshot a, String userId, Instant now) {
    if (!"live".equals(a.status)) return Rejection.NOT_LIVE;
    if (now.isBefore(a.startsAt)) return Rejection.NOT_STARTED;
    if (!now.isBefore(a.endsAt)) return Rejection.ALREADY_ENDED;
    // Тэргүүлж буй хэрэглэгч дахин санал илгээж болно (1 эрх зарцуулна).
    return null;
  }

  /** Үнийн алхам зөвшөөрөгдөх эсэх: null (auction-ы increment) эсвэл 1..5. */
  public static boolean validStep(Integer step) {
    return step == null || (step >= 1 && step <= 5);
  }

  /** Шинэ үнэ = одоогийн үнэ + (сонгосон алхам, байхгүй бол auction-ы increment). */
  public static int nextPrice(int currentPrice, int increment, Integer step) {
    return currentPrice + (step != null ? step : increment);
  }

  /**
   * Soft-close сунгалт: дуусахад softCloseSec-ээс бага хугацаа үлдсэн үед санал ирвэл
   * `now + extendSec` хүртэл сунгана (одоогийн endsAt-ээс богиносгохгүй,
   * hardCloseAt-ээс хэтрүүлэхгүй).
   */
  public static Instant computeNewEndsAt(Snapshot a, Instant now) {
    if (a.rounds != null && !a.rounds.isEmpty()) {
      // Раундтай: тоолуур одоогийн раундын хугацаагаар шинээр эхэлнэ (өмнөхөөс эрт байж болно)
      Round r = AuctionRounds.roundAt(a.rounds, now);
      Instant next = now.plusSeconds(r.durationSec());
      if (a.hardCloseAt != null && next.isAfter(a.hardCloseAt)) next = a.hardCloseAt;
      return next;
    }
    long msLeft = a.endsAt.toEpochMilli() - now.toEpochMilli();
    if (msLeft > a.softCloseSec * 1000L) return a.endsAt;
    Instant extended = now.plusSeconds(a.extendSec);
    if (extended.isBefore(a.endsAt)) extended = a.endsAt;
    if (a.hardCloseAt != null && extended.isAfter(a.hardCloseAt)) extended = a.hardCloseAt;
    return extended;
  }

  /**
   * 2/3-р байрыг тодруулна: саналын дарааллаар (шинэ нь түрүүлж) ирсэн хэрэглэгчдээс
   * ялагчийг хасч, давхардлыг нэг болгон эхний `max` хүнийг буцаана.
   * Нэг хэрэглэгчийн олон санал нэг л тоологдоно.
   */
  public static List<String> pickRunnersUp(List<String> bidderIdsNewestFirst, String winnerId, int max) {
    java.util.Set<String> seen = new java.util.LinkedHashSet<>();
    for (String u : bidderIdsNewestFirst) {
      if (seen.size() >= max) break;
      if (u != null && !u.equals(winnerId)) seen.add(u);
    }
    return List.copyOf(seen);
  }

  static Snapshot fromRow(Map<String, Object> r) {
    Snapshot s = new Snapshot();
    s.status = (String) r.get("status");
    s.startsAt = (Instant) r.get("startsAt");
    s.endsAt = (Instant) r.get("endsAt");
    s.currentPrice = intOf(r.get("currentPrice"));
    s.increment = intOf(r.get("increment"));
    s.softCloseSec = intOf(r.get("softCloseSec"));
    s.extendSec = intOf(r.get("extendSec"));
    s.hardCloseAt = (Instant) r.get("hardCloseAt");
    s.lastBidderId = (String) r.get("lastBidderId");
    s.bidCount = intOf(r.get("bidCount"));
    s.rounds = AuctionRounds.parse((String) r.get("rounds"));
    return s;
  }

  private static int intOf(Object o) {
    return o == null ? 0 : ((Number) o).intValue();
  }
}
