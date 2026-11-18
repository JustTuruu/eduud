package mn.eduud.categories;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import mn.eduud.common.ApiException;
import org.junit.jupiter.api.Test;

class CategoryRulesTest {
  @Test
  void nameIsTrimmed() {
    assertThat(CategoryRules.validateName("  Электроник ")).isEqualTo("Электроник");
  }

  @Test
  void emptyOrTooLongRejected() {
    assertThatThrownBy(() -> CategoryRules.validateName("   ")).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> CategoryRules.validateName(null)).isInstanceOf(ApiException.class);
    assertThatThrownBy(() -> CategoryRules.validateName("a".repeat(41))).isInstanceOf(ApiException.class);
  }

  @Test
  void boundariesAccepted() {
    assertThat(CategoryRules.validateName("a")).hasSize(1);
    assertThat(CategoryRules.validateName("a".repeat(40))).hasSize(40);
  }
}
