package mn.eduud.kafka;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import mn.eduud.config.AppProperties;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.ListOffsetsResult.ListOffsetsResultInfo;
import org.apache.kafka.clients.admin.OffsetSpec;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.utils.Utils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Ялагч тодруулахаас өмнө "замд яваа" санал үлдээгүйг шалгана (FR-13: lag = 0).
 * Auction-ы partition-ийг producer-ийн анхдагч partitioner-тэй ижлээр (murmur2) тооцоод
 * consumer group-ийн commit хийсэн offset-ийг partition-ийн сүүлийн offset-той харьцуулна.
 */
@Component
@ConditionalOnProperty(name = "app.bid.mode", havingValue = "kafka", matchIfMissing = true)
public class PartitionLagChecker {
  private static final Logger log = LoggerFactory.getLogger(PartitionLagChecker.class);

  private final AdminClient admin;
  private final String topic;
  private final int partitions;
  private final String groupId;

  public PartitionLagChecker(
      AdminClient admin, AppProperties props, @Value("${spring.kafka.consumer.group-id}") String groupId) {
    this.admin = admin;
    this.topic = props.bid().topic();
    this.partitions = props.bid().topicPartitions();
    this.groupId = groupId;
  }

  public int partitionOf(String auctionId) {
    byte[] key = auctionId.getBytes(StandardCharsets.UTF_8);
    return Utils.toPositive(Utils.murmur2(key)) % partitions;
  }

  /** @return боловсруулагдаагүй message байвал тэдгээрийн тоо, мэдэх боломжгүй бол -1. */
  public long lag(String auctionId) {
    TopicPartition tp = new TopicPartition(topic, partitionOf(auctionId));
    try {
      Map<TopicPartition, ListOffsetsResultInfo> end =
          admin.listOffsets(Map.of(tp, OffsetSpec.latest())).all().get(3, TimeUnit.SECONDS);
      Map<TopicPartition, OffsetAndMetadata> committed =
          admin.listConsumerGroupOffsets(groupId).partitionsToOffsetAndMetadata().get(3, TimeUnit.SECONDS);
      long endOffset = end.get(tp).offset();
      OffsetAndMetadata c = committed.get(tp);
      long committedOffset = c == null ? 0 : c.offset();
      return Math.max(0, endOffset - committedOffset);
    } catch (Exception e) {
      log.warn("Lag шалгаж чадсангүй ({}): {}", tp, e.getMessage());
      return -1;
    }
  }
}
