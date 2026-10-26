package mn.eduud.kafka;

import java.util.ArrayList;
import java.util.List;
import mn.eduud.auctions.BidCommand;
import mn.eduud.auctions.BidProcessor;
import mn.eduud.auctions.BidProcessor.Incoming;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.listener.BatchListenerFailedException;
import org.springframework.kafka.support.serializer.DeserializationException;
import org.springframework.stereotype.Component;

/**
 * `auction.bids`-ийн consumer (bid-processor). Partition бүрийг зөвхөн нэг thread уншина,
 * тиймээс нэг auction-ы саналууд offset-ийн дарааллаар (FIFO) боловсрогдоно.
 *
 * <p>Poll хийсэн багцыг эхлээд нэг транзакцаар боловсруулна. Амжилтгүй бол message
 * бүрийг тусад нь оролдож, алдаатай message-ийг BatchListenerFailedException-оор
 * заана: түүнээс өмнөх offset-ууд commit болж, алдаатай нь retry → DLT руу явна.
 */
@Component
@ConditionalOnProperty(name = "app.bid.mode", havingValue = "kafka", matchIfMissing = true)
public class BidConsumer {
  private static final Logger log = LoggerFactory.getLogger(BidConsumer.class);
  private final BidProcessor processor;

  public BidConsumer(BidProcessor processor) {
    this.processor = processor;
  }

  @KafkaListener(
      id = "bid-processor",
      topics = "${app.bid.topic}",
      containerFactory = "bidListenerFactory")
  public void onBatch(List<ConsumerRecord<String, BidCommand>> records) {
    // ErrorHandlingDeserializer: задарч чадаагүй message-ийн value null байна
    int poison = -1;
    for (int i = 0; i < records.size(); i++) {
      if (records.get(i).value() == null) {
        poison = i;
        break;
      }
    }
    List<ConsumerRecord<String, BidCommand>> valid = poison < 0 ? records : records.subList(0, poison);

    if (!valid.isEmpty()) {
      try {
        processor.process(toIncoming(valid));
      } catch (Exception batchError) {
        log.warn("Багц ({} message) амжилтгүй, нэг нэгээр нь оролдоно: {}", valid.size(), batchError.getMessage());
        for (int i = 0; i < valid.size(); i++) {
          try {
            processor.process(toIncoming(List.of(valid.get(i))));
          } catch (Exception e) {
            throw new BatchListenerFailedException("Санал боловсруулахад алдаа", e, i);
          }
        }
      }
    }
    if (poison >= 0) {
      // DeserializationException-ийг DefaultErrorHandler retry хийлгүй шууд DLT руу илгээнэ
      ConsumerRecord<String, BidCommand> bad = records.get(poison);
      throw new BatchListenerFailedException(
          "Message задарсангүй",
          new DeserializationException("Message задарсангүй: " + bad.topic() + "-" + bad.partition() + "@" + bad.offset(), null, false, null),
          poison);
    }
  }

  private static List<Incoming> toIncoming(List<ConsumerRecord<String, BidCommand>> records) {
    List<Incoming> list = new ArrayList<>(records.size());
    for (ConsumerRecord<String, BidCommand> r : records) {
      list.add(new Incoming(r.value(), r.partition(), r.offset()));
    }
    return list;
  }
}
