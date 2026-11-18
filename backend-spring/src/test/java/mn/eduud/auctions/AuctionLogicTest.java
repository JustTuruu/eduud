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
  void acceptsConsecutiveBidBySameUser() {
    // Arrange
    Snapshot s = live(T0.plusSeconds(600), null);
    s.lastBidderId = "u1";

    // Act
    Rejection same = AuctionLogic.validateBid(s, "u1", T0);
    Rejection other = AuctionLogic.validateBid(s, "u2", T0);

    // Assert
    assertThat(same).isNull();
    assertThat(other).isNull();
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

  // ---------- Раундтай ----------

  private static Instant at(int min) {
    return T0.plusSeconds(min * 60L);
  }

  /** R1 [0,180) 3600с, R2 [180,240) 45м=2700с, [завсар 240-300], R3 [300,310) 30с. */
  private static java.util.List<AuctionRounds.Round> sample() {
    return java.util.List.of(
        new AuctionRounds.Round(at(0), at(180), 3600),
        new AuctionRounds.Round(at(180), at(240), 2700),
        new AuctionRounds.Round(at(300), at(310), 30));
  }

  @Test
  void roundAtInsideBoundaryBeforeGapAfter() {
    var r = sample();
    assertThat(AuctionRounds.roundAt(r, at(10))).isEqualTo(r.get(0));
    assertThat(AuctionRounds.roundAt(r, at(180))).isEqualTo(r.get(1)); // хил: endsAt орохгүй
    assertThat(AuctionRounds.roundAt(r, at(0))).isEqualTo(r.get(0));
    assertThat(AuctionRounds.roundAt(r, at(-5))).isEqualTo(r.get(0)); // эхнээс өмнө
    assertThat(AuctionRounds.roundAt(r, at(270))).isEqualTo(r.get(1)); // завсар
    assertThat(AuctionRounds.roundAt(r, at(400))).isEqualTo(r.get(2)); // сүүлээс хойш
  }

  @Test
  void roundsFirstBidShortensFromLastRoundEnd() {
    Snapshot s = live(at(310), null);
    s.rounds = sample();
    assertThat(AuctionLogic.computeNewEndsAt(s, at(5))).isEqualTo(at(5).plusSeconds(3600));
  }

  @Test
  void roundsResetUsesCurrentRoundDurationAndMayBeEarlier() {
    Snapshot s = live(at(65), null);
    s.rounds = sample();
    Instant now = at(200);
    assertThat(AuctionLogic.computeNewEndsAt(s, now)).isEqualTo(now.plusSeconds(2700));
    Instant late = at(305);
    s.endsAt = late.plusSeconds(3000);
    assertThat(AuctionLogic.computeNewEndsAt(s, late)).isEqualTo(late.plusSeconds(30));
  }

  @Test
  void roundsRespectHardCloseCap() {
    Snapshot s = live(at(310), at(20));
    s.rounds = sample();
    assertThat(AuctionLogic.computeNewEndsAt(s, at(5))).isEqualTo(at(20));
  }

  @Test
  void softCloseUnchangedWhenRoundsNull() {
    Snapshot s = live(T0.plusSeconds(10), null);
    assertThat(s.rounds).isNull();
    assertThat(AuctionLogic.computeNewEndsAt(s, T0)).isEqualTo(T0.plusSeconds(20));
  }

  @Test
  void validatesRounds() {
    org.assertj.core.api.Assertions.assertThatCode(() -> AuctionRounds.validate(sample())).doesNotThrowAnyException();
    var bad = java.util.List.of(new AuctionRounds.Round(at(10), at(5), 10));
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuctionRounds.validate(bad))
        .isInstanceOf(mn.eduud.common.ApiException.class);
    var zero = java.util.List.of(new AuctionRounds.Round(at(0), at(5), 0));
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuctionRounds.validate(zero))
        .isInstanceOf(mn.eduud.common.ApiException.class);
    var overlap =
        java.util.List.of(new AuctionRounds.Round(at(0), at(10), 5), new AuctionRounds.Round(at(5), at(20), 5));
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuctionRounds.validate(overlap))
        .isInstanceOf(mn.eduud.common.ApiException.class);
    org.assertj.core.api.Assertions.assertThatThrownBy(() -> AuctionRounds.validate(java.util.List.of()))
        .isInstanceOf(mn.eduud.common.ApiException.class);
  }

  @Test
  void parseAndToJsonRoundTrip() {
    var r = sample();
    assertThat(AuctionRounds.parse(AuctionRounds.toJson(r))).isEqualTo(r);
    assertThat(AuctionRounds.parse(null)).isNull();
  }

  @Test
  void defaultScheduleTemplate() {
    var d = AuctionRounds.defaultSchedule(T0);
    assertThat(d).hasSize(11);
    assertThat(d.get(0).endsAt()).isEqualTo(T0.plusSeconds(3 * 3600));
    assertThat(d.get(0).durationSec()).isEqualTo(3600);
    assertThat(d.stream().map(AuctionRounds.Round::durationSec).toList())
        .containsExactly(3600, 2700, 1800, 1200, 600, 300, 180, 60, 30, 10, 5);
    assertThat(d.get(10).endsAt()).isEqualTo(T0.plusSeconds(3 * 3600 + 7 * 3600 + 3 * 2400));
    AuctionRounds.validate(d);
  }

  @Test
  void validStepAcceptsNullAndOneToFive() {
    assertThat(AuctionLogic.validStep(null)).isTrue();
    for (int i = 1; i <= 5; i++) assertThat(AuctionLogic.validStep(i)).isTrue();
    assertThat(AuctionLogic.validStep(0)).isFalse();
    assertThat(AuctionLogic.validStep(6)).isFalse();
    assertThat(AuctionLogic.validStep(-1)).isFalse();
  }

  @Test
  void nextPriceUsesStepOrIncrement() {
    assertThat(AuctionLogic.nextPrice(1000, 10, null)).isEqualTo(1010);
    assertThat(AuctionLogic.nextPrice(1000, 10, 3)).isEqualTo(1003);
    assertThat(AuctionLogic.nextPrice(1000, 10, 5)).isEqualTo(1005);
  }
}
