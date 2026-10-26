package mn.eduud.auctions;

import java.time.Instant;
import java.util.Map;

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
  }

  public enum Rejection {
    NOT_LIVE("Дуудлага худалдаа идэвхгүй байна."),
    NOT_STARTED("Дуудлага худалдаа хараахан эхлээгүй байна."),
    ALREADY_ENDED("Дуудлага худалдаа дууссан байна."),
    ALREADY_LAST_BIDDER("Та хамгийн сүүлийн санал өгсөн хүн байна."),
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
    if (userId.equals(a.lastBidderId)) return Rejection.ALREADY_LAST_BIDDER;
    return null;
  }

  /**
   * Soft-close сунгалт: дуусахад softCloseSec-ээс бага хугацаа үлдсэн үед санал ирвэл
   * `now + extendSec` хүртэл сунгана (одоогийн endsAt-ээс богиносгохгүй,
   * hardCloseAt-ээс хэтрүүлэхгүй).
   */
  public static Instant computeNewEndsAt(Snapshot a, Instant now) {
    long msLeft = a.endsAt.toEpochMilli() - now.toEpochMilli();
    if (msLeft > a.softCloseSec * 1000L) return a.endsAt;
    Instant extended = now.plusSeconds(a.extendSec);
    if (extended.isBefore(a.endsAt)) extended = a.endsAt;
    if (a.hardCloseAt != null && extended.isAfter(a.hardCloseAt)) extended = a.hardCloseAt;
    return extended;
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
    return s;
  }

  private static int intOf(Object o) {
    return o == null ? 0 : ((Number) o).intValue();
  }
}
