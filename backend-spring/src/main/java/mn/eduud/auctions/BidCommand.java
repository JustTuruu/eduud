package mn.eduud.auctions;

/**
 * `auction.bids` topic-ийн message. Key = auctionId (нэг auction-ы бүх санал нэг partition-д).
 *
 * @param bidId API дээр үүссэн UUID — idempotency-ийн үндэс
 * @param step хэрэглэгчийн сонгосон үнийн алхам (1..5 ₮); null бол auction-ы `increment` (хуучин message/k6)
 * @param receivedAtMs API хүлээн авсан серверийн цаг (эрэмбийн эх сурвалж, BR-13)
 */
public record BidCommand(String bidId, String auctionId, String userId, long receivedAtMs, int schemaVersion, Integer step) {
  public static final int SCHEMA_VERSION = 1;

  /** `step`-гүй (хуучин) message-ийг дэмжих тохиромжтой constructor. */
  public BidCommand(String bidId, String auctionId, String userId, long receivedAtMs, int schemaVersion) {
    this(bidId, auctionId, userId, receivedAtMs, schemaVersion, null);
  }
}
