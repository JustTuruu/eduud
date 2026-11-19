package mn.eduud.auctions;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.Test;

class RunnersUpTest {
  @Test
  void skipsWinnerAndDeduplicates() {
    // шинэ -> хуучин: W, B, W, B, C, A, C
    List<String> r = AuctionLogic.pickRunnersUp(List.of("W", "B", "W", "B", "C", "A", "C"), "W", 2);
    assertThat(r).containsExactly("B", "C");
  }

  @Test
  void fewerBidders() {
    assertThat(AuctionLogic.pickRunnersUp(List.of("W", "W"), "W", 2)).isEmpty();
    assertThat(AuctionLogic.pickRunnersUp(List.of("W", "B", "W"), "W", 2)).containsExactly("B");
    assertThat(AuctionLogic.pickRunnersUp(List.of(), "W", 2)).isEmpty();
  }

  @Test
  void respectsMaxAndIgnoresNulls() {
    assertThat(AuctionLogic.pickRunnersUp(Arrays.asList("W", null, "B", "C", "D"), "W", 2)).containsExactly("B", "C");
  }
}
