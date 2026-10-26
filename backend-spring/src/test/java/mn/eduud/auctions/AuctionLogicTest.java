package mn.eduud.auctions;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import mn.eduud.auctions.AuctionLogic.Rejection;
import mn.eduud.auctions.AuctionLogic.Snapshot;
import org.junit.jupiter.api.Test;

class AuctionLogicTest {
  private static final Instant T0 = Instant.parse("2026-01-01T10:00:00Z");

  private static Snapshot live(Instant endsAt, Instant hardCloseAt) {
    Snapshot s = new Snapshot();
    s.status = "live";
    s.startsAt = T0.minusSeconds(3600);
    s.endsAt = endsAt;
    s.currentPrice = 1000;
    s.increment = 10;
    s.softCloseSec = 30;
    s.extendSec = 20;
    s.hardCloseAt = hardCloseAt;
    return s;
  }

  @Test
  void acceptsValidBid() {
    assertThat(AuctionLogic.validateBid(live(T0.plusSeconds(600), null), "u1", T0)).isNull();
  }

  @Test
  void rejectsWhenNotLive() {
    Snapshot s = live(T0.plusSeconds(600), null);
    s.status = "scheduled";
    assertThat(AuctionLogic.validateBid(s, "u1", T0)).isEqualTo(Rejection.NOT_LIVE);
  }

  @Test
  void rejectsBeforeStart() {
    Snapshot s = live(T0.plusSeconds(600), null);
    s.startsAt = T0.plusSeconds(10);
    assertThat(AuctionLogic.validateBid(s, "u1", T0)).isEqualTo(Rejection.NOT_STARTED);
  }

  @Test
  void rejectsAtOrAfterEnd() {
    assertThat(AuctionLogic.validateBid(live(T0, null), "u1", T0)).isEqualTo(Rejection.ALREADY_ENDED);
  }

  @Test
  void rejectsConsecutiveBidBySameUser() {
    Snapshot s = live(T0.plusSeconds(600), null);
    s.lastBidderId = "u1";
    assertThat(AuctionLogic.validateBid(s, "u1", T0)).isEqualTo(Rejection.ALREADY_LAST_BIDDER);
    assertThat(AuctionLogic.validateBid(s, "u2", T0)).isNull();
  }

  @Test
  void noExtensionOutsideSoftCloseWindow() {
    Snapshot s = live(T0.plusSeconds(600), null);
    assertThat(AuctionLogic.computeNewEndsAt(s, T0)).isEqualTo(T0.plusSeconds(600));
  }

  @Test
  void extendsInsideSoftCloseWindow() {
    Snapshot s = live(T0.plusSeconds(10), null);
    assertThat(AuctionLogic.computeNewEndsAt(s, T0)).isEqualTo(T0.plusSeconds(20));
  }

  @Test
  void neverShortensEndsAt() {
    Snapshot s = live(T0.plusSeconds(25), null);
    s.extendSec = 5;
    assertThat(AuctionLogic.computeNewEndsAt(s, T0)).isEqualTo(T0.plusSeconds(25));
  }

  @Test
  void capsAtHardClose() {
    Snapshot s = live(T0.plusSeconds(10), T0.plusSeconds(15));
    assertThat(AuctionLogic.computeNewEndsAt(s, T0)).isEqualTo(T0.plusSeconds(15));
  }
}
