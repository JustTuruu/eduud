package mn.eduud.auctions;

/**
 * `auction.bids` topic-ийн message. Key = auctionId (нэг auction-ы бүх санал нэг partition-д).
 *
 * @param bidId API дээр үүссэн UUID — idempotency-ийн үндэс
 * @param receivedAtMs API хүлээн авсан серверийн цаг (эрэмбийн эх сурвалж, BR-13)
 */
public record BidCommand(String bidId, String auctionId, String userId, long receivedAtMs, int schemaVersion) {
  public static final int SCHEMA_VERSION = 1;
}
