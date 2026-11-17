package mn.eduud.requests;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.eduud.common.ApiException;
import org.junit.jupiter.api.Test;

class AuctionRequestRulesTest {
  @Test
  void titleIsTrimmed() {
    assertThat(AuctionRequestRules.validateTitle("  Хуучин цаг  ")).isEqualTo("Хуучин цаг");
  }

  @Test
  void titleTooShortOrLongRejected() {
    assertThatThrownBy(() -> AuctionRequestRules.validateTitle(" ab ")).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateTitle("a".repeat(121))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateTitle(null)).isInstanceOf(ApiException.class);
  }

  @Test
  void titleBoundariesAccepted() {
    assertThat(AuctionRequestRules.validateTitle("abc")).hasSize(3);
    assertThat(AuctionRequestRules.validateTitle("a".repeat(120))).hasSize(120);
  }

  @Test
  void descriptionBoundaries() {
    assertThat(AuctionRequestRules.validateDescription("a".repeat(10))).hasSize(10);
    assertThat(AuctionRequestRules.validateDescription("a".repeat(4000))).hasSize(4000);
    assertThatThrownBy(() -> AuctionRequestRules.validateDescription("a".repeat(9))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateDescription("a".repeat(4001)))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void startPriceRange() {
    assertThat(AuctionRequestRules.validateStartPrice(null)).isNull();
    assertThat(AuctionRequestRules.validateStartPrice(0L)).isZero();
    assertThat(AuctionRequestRules.validateStartPrice(1_000_000_000L)).isEqualTo(1_000_000_000);
    assertThatThrownBy(() -> AuctionRequestRules.validateStartPrice(-1L)).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateStartPrice(1_000_000_001L)).isInstanceOf(ApiException.class);
  }

  @Test
  void optionalFieldsTrimmedAndLimited() {
    assertThat(AuctionRequestRules.validateOptional("   ", "Ангилал")).isNull();
    assertThat(AuctionRequestRules.validateOptional(" x ", "Ангилал")).isEqualTo("x");
    assertThatThrownBy(() -> AuctionRequestRules.validateOptional("a".repeat(1001), "Ангилал"))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void initialStatusDependsOnDraftFlag() {
    assertThat(AuctionRequestRules.initialStatus(true)).isEqualTo("draft");
    assertThat(AuctionRequestRules.initialStatus(false)).isEqualTo("pending");
    assertThat(AuctionRequestRules.initialStatus(null)).isEqualTo("pending");
  }

  @Test
  void editableOnlyDraftAndInfoRequested() {
    assertThat(AuctionRequestRules.canEdit("draft")).isTrue();
    assertThat(AuctionRequestRules.canEdit("info_requested")).isTrue();
    assertThat(AuctionRequestRules.canEdit("pending")).isFalse();
    assertThat(AuctionRequestRules.canEdit("approved")).isFalse();
  }

  @Test
  void cancellableStates() {
    assertThat(AuctionRequestRules.canCancel("draft")).isTrue();
    assertThat(AuctionRequestRules.canCancel("pending")).isTrue();
    assertThat(AuctionRequestRules.canCancel("info_requested")).isTrue();
    assertThat(AuctionRequestRules.canCancel("reviewing")).isFalse();
    assertThat(AuctionRequestRules.canCancel("approved")).isFalse();
    assertThat(AuctionRequestRules.canCancel("cancelled")).isFalse();
  }

  @Test
  void submitMovesToPending() {
    assertThat(AuctionRequestRules.statusAfterEdit("draft", true)).isEqualTo("pending");
    assertThat(AuctionRequestRules.statusAfterEdit("info_requested", true)).isEqualTo("pending");
    assertThat(AuctionRequestRules.statusAfterEdit("draft", false)).isEqualTo("draft");
  }

  @Test
  void decisionRequiresNoteForRejectAndInfoRequest() {
    assertThatThrownBy(() -> AuctionRequestRules.validateDecision("rejected", "  ")).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateDecision("info_requested", null))
        .isInstanceOf(ApiException.class);
    assertThat(AuctionRequestRules.validateDecision("rejected", " Шалтгаан ")).isEqualTo("Шалтгаан");
    assertThat(AuctionRequestRules.validateDecision("approved", null)).isNull();
    assertThat(AuctionRequestRules.validateDecision("reviewing", "")).isNull();
  }

  @Test
  void decisionRejectsUnknownStatus() {
    assertThatThrownBy(() -> AuctionRequestRules.validateDecision("draft", "x")).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> AuctionRequestRules.validateDecision(null, "x")).isInstanceOf(ApiException.class);
  }

  @Test
  void decidableStates() {
    assertThat(AuctionRequestRules.canDecide("pending")).isTrue();
    assertThat(AuctionRequestRules.canDecide("reviewing")).isTrue();
    assertThat(AuctionRequestRules.canDecide("info_requested")).isTrue();
    assertThat(AuctionRequestRules.canDecide("draft")).isFalse();
    assertThat(AuctionRequestRules.canDecide("approved")).isFalse();
    assertThat(AuctionRequestRules.canDecide("cancelled")).isFalse();
  }
}
