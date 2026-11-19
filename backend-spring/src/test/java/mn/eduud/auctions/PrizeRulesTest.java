package mn.eduud.auctions;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import mn.eduud.auctions.PrizeRules.Prize;
import mn.eduud.common.ApiException;
import org.junit.jupiter.api.Test;

class PrizeRulesTest {
  @Test
  void nullOrEmptyIsEmpty() {
    assertThat(PrizeRules.validate(null)).isEmpty();
    assertThat(PrizeRules.validate(List.of())).isEmpty();
  }

  @Test
  void validPrizesNormalizedAndSorted() {
    List<Prize> out =
        PrizeRules.validate(List.of(new Prize(3, "item", 5, "  AirPods "), new Prize(2, "tokens", 50, "x")));
    assertThat(out).containsExactly(new Prize(2, "tokens", 50, null), new Prize(3, "item", null, "AirPods"));
  }

  @Test
  void invalidPlaceRejected() {
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(1, "tokens", 5, null)))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(4, "tokens", 5, null)))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(null, "tokens", 5, null)))).isInstanceOf(ApiException.class);
  }

  @Test
  void duplicatePlaceRejected() {
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "tokens", 5, null), new Prize(2, "item", null, "a"))))
        .isInstanceOf(ApiException.class);
  }

  @Test
  void tokenBounds() {
    assertThat(PrizeRules.validate(List.of(new Prize(2, "tokens", 1, null)))).hasSize(1);
    assertThat(PrizeRules.validate(List.of(new Prize(2, "tokens", 100000, null)))).hasSize(1);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "tokens", 0, null)))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "tokens", 100001, null)))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "tokens", null, null)))).isInstanceOf(ApiException.class);
  }

  @Test
  void itemTitleBounds() {
    assertThat(PrizeRules.validate(List.of(new Prize(2, "item", null, "a".repeat(120))))).hasSize(1);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "item", null, "   ")))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "item", null, null)))).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "item", null, "a".repeat(121))))).isInstanceOf(ApiException.class);
  }

  @Test
  void unknownKindRejected() {
    assertThatThrownBy(() -> PrizeRules.validate(List.of(new Prize(2, "cash", 5, "a")))).isInstanceOf(ApiException.class);
  }
}
