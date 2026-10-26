package mn.eduud.auctions;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import mn.eduud.config.AppProperties;
import mn.eduud.kafka.PartitionLagChecker;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * NestJS-ийн pg-boss job-уудыг орлоно. Санал бүрт job товлохын оронд DB-г тогтмол
 * (анхдагч 250 мс) шалгана — сервер дахин асахад сэргээх шаардлагагүй, санал бүрт
 * нэмэлт бичилт хийхгүй.
 *
 * <p>Kafka горимд auction-ыг хаахаас өмнө түүний partition-д боловсруулагдаагүй message
 * үлдээгүйг (lag = 0) шалгана — API хүлээн авсан ч consumer-т хүрээгүй санал алдагдахгүй.
 */
@Component
public class AuctionScheduler {
  private static final Logger log = LoggerFactory.getLogger(AuctionScheduler.class);

  private final AuctionsService auctions;
  private final PartitionLagChecker lagChecker;
  private final long maxWaitMs;
  private final Map<String, Long> waitingSince = new ConcurrentHashMap<>();

  private final boolean enabled;

  public AuctionScheduler(
      AuctionsService auctions,
      ObjectProvider<PartitionLagChecker> lagChecker,
      AppProperties props,
      @org.springframework.beans.factory.annotation.Value("${app.runtime-enabled:true}") boolean enabled) {
    this.enabled = enabled;
    this.auctions = auctions;
    this.lagChecker = lagChecker.getIfAvailable();
    this.maxWaitMs = props.scheduler().maxFinalizeWaitMs();
  }

  @Scheduled(fixedDelayString = "${app.scheduler.tick-ms}")
  public void tick() {
    if (!enabled) return;
    try {
      auctions.startDue();
      for (String id : auctions.dueForFinalize(50)) {
        if (canFinalize(id)) {
          auctions.finalizeAuction(id);
          waitingSince.remove(id);
        }
      }
      auctions.expireOrders();
    } catch (Exception e) {
      log.warn("Scheduler tick алдаа (DB бэлэн биш байж магадгүй): {}", e.getMessage());
    }
  }

  private boolean canFinalize(String auctionId) {
    if (lagChecker == null) return true; // direct горим
    long lag = lagChecker.lag(auctionId);
    if (lag == 0) return true;
    long since = waitingSince.computeIfAbsent(auctionId, k -> System.currentTimeMillis());
    if (System.currentTimeMillis() - since > maxWaitMs) {
      log.warn("Auction {}: partition lag={} {} мс-ээс удаан буурсангүй, хааж байна", auctionId, lag, maxWaitMs);
      return true;
    }
    return false;
  }
}
