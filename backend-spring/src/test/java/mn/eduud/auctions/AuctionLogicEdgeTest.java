package mn.eduud.auctions;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import mn.eduud.auctions.AuctionLogic.Rejection;
import mn.eduud.auctions.AuctionLogic.Snapshot;
import org.junit.jupiter.api.Test;

/** Lab 10: AuctionLogic-ийн хэвийн болон хязгаарын тохиолдлын тест (AAA бүтэцтэй). */
class AuctionLogicEdgeTest {
  private static final Instant T0 = Instant.parse("2026-01-01T10:00:00Z");

  private static Snapshot live(Instant endsAt) {
    Snapshot s = new Snapshot();
    s.status = "live";
    s.startsAt = T0.minusSeconds(3600);
    s.endsAt = endsAt;
    s.softCloseSec = 30;
    s.extendSec = 20;
    return s;
  }

  // ---- Хэвийн тохиолдол ----

  @Test
  void validateBid_otherUserThanLastBidder_isAccepted() {
    // Arrange
    Snapshot s = live(T0.plusSeconds(600));
    s.lastBidderId = "u1";

    // Act
    Rejection result = AuctionLogic.validateBid(s, "u2", T0);

    // Assert
    assertThat(result).isNull();
  }

  @Test
  void computeNewEndsAt_insideSoftClose_extendsFromNow() {
    // Arrange
    Snapshot s = live(T0.plusSeconds(10));

    // Act
    Instant result = AuctionLogic.computeNewEndsAt(s, T0);

    // Assert
    assertThat(result).isEqualTo(T0.plusSeconds(20));
  }

  // ---- Хязгаарын (edge) тохиолдол ----

  @Test
  void validateBid_noLastBidder_nullIsAccepted() {
    // Arrange: lastBidderId = null (анхны санал)
    Snapshot s = live(T0.plusSeconds(600));

    // Act
    Rejection result = AuctionLogic.validateBid(s, "u1", T0);

    // Assert
    assertThat(result).isNull();
  }

  @Test
  void validateBid_oneMillisecondBeforeEnd_isAccepted() {
    // Arrange: дуусахаас яг 1 мс өмнө — хязгаарын доод тал
    Snapshot s = live(T0);

    // Act
    Rejection result = AuctionLogic.validateBid(s, "u1", T0.minusMillis(1));

    // Assert
    assertThat(result).isNull();
  }

  @Test
  void validateBid_exactlyAtStart_isNotRejectedAsNotStarted() {
    // Arrange: now == startsAt
    Snapshot s = live(T0.plusSeconds(600));
    s.startsAt = T0;

    // Act
    Rejection result = AuctionLogic.validateBid(s, "u1", T0);

    // Assert
    assertThat(result).isNull();
  }

  @Test
  void computeNewEndsAt_exactlyAtSoftCloseBoundary_extends() {
    // Arrange: үлдсэн хугацаа = softCloseSec (30с) — хязгаарт сунгана
    Snapshot s = live(T0.plusSeconds(30));
    s.extendSec = 60;

    // Act
    Instant result = AuctionLogic.computeNewEndsAt(s, T0);

    // Assert
    assertThat(result).isEqualTo(T0.plusSeconds(60));
  }

  @Test
  void computeNewEndsAt_veryLargeExtendSec_cappedByHardClose() {
    // Arrange: маш том extendSec, hardCloseAt-аас хэтэрч болохгүй
    Snapshot s = live(T0.plusSeconds(5));
    s.extendSec = Integer.MAX_VALUE;
    s.hardCloseAt = T0.plusSeconds(100);

    // Act
    Instant result = AuctionLogic.computeNewEndsAt(s, T0);

    // Assert
    assertThat(result).isEqualTo(T0.plusSeconds(100));
  }

  @Test
  void computeNewEndsAt_alreadyPastEnd_negativeTimeLeftStillNeverShortens() {
    // Arrange: endsAt өнгөрсөн (үлдсэн хугацаа сөрөг), extendSec = 0
    Snapshot s = live(T0.minusSeconds(5));
    s.extendSec = 0;

    // Act
    Instant result = AuctionLogic.computeNewEndsAt(s, T0);

    // Assert: now + 0 нь endsAt-ээс хойно тул now буцна, endsAt-ээс богино болохгүй
    assertThat(result).isAfterOrEqualTo(s.endsAt);
  }
}
