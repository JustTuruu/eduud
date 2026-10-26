package mn.eduud.auctions;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthAnnotations.Public;
import mn.eduud.common.auth.AuthUser;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/auctions")
public class AuctionsController {
  private final AuctionsService auctions;
  private final BidService bids;

  public AuctionsController(AuctionsService auctions, BidService bids) {
    this.auctions = auctions;
    this.bids = bids;
  }

  @Public
  @GetMapping
  public List<Map<String, Object>> list(@RequestParam(required = false) String status) {
    return auctions.list(status);
  }

  @Public
  @GetMapping("/{id}")
  public Map<String, Object> detail(@PathVariable UUID id) {
    return auctions.detail(id.toString());
  }

  @PostMapping("/{id}/bid")
  public ResponseEntity<Map<String, Object>> bid(@CurrentUser AuthUser user, @PathVariable UUID id) {
    return bids.placeBid(id.toString(), user.id());
  }
}
