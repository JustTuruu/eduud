package mn.eduud.kafka;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import mn.eduud.auctions.BidCommand;
import mn.eduud.config.AppProperties;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.common.serialization.ByteArraySerializer;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.autoconfigure.kafka.KafkaProperties;
import org.springframework.boot.ssl.SslBundles;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.config.TopicBuilder;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaProducerFactory;
import org.springframework.kafka.core.KafkaAdmin;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.MicrometerConsumerListener;
import org.springframework.kafka.core.MicrometerProducerListener;
import org.springframework.kafka.listener.DeadLetterPublishingRecoverer;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.kafka.support.serializer.ErrorHandlingDeserializer;
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.JsonSerializer;
import org.springframework.kafka.support.ExponentialBackOffWithMaxRetries;
import io.micrometer.core.instrument.MeterRegistry;

/**
 * Kafka-гийн тохиргоо (тайлангийн 5-р бүлэг):
 * <ul>
 *   <li>`auction.bids` — key = auctionId, 12 partition (BID_TOPIC_PARTITIONS)</li>
 *   <li>Producer: acks=all + idempotent — дахин илгээлтээс давхардал/эрэмбийн алдаа гарахгүй</li>
 *   <li>Consumer: batch listener, partition тоотой тэнцүү concurrency</li>
 *   <li>Алдаа: 1с → 4с → 16с хоцролттой 3 удаа дахин оролдоод `auction.bids.DLT` руу (FR-22).
 *       Retry нь blocking тул partition доторх дараалал алдагдахгүй.</li>
 * </ul>
 */
@Configuration
@ConditionalOnProperty(name = "app.bid.mode", havingValue = "kafka", matchIfMissing = true)
public class KafkaConfig {
  public static final String DLT_SUFFIX = ".DLT";

  private final AppProperties.Bid bid;
  private final boolean runtimeEnabled;

  public KafkaConfig(
      AppProperties props, @org.springframework.beans.factory.annotation.Value("${app.runtime-enabled:true}") boolean runtimeEnabled) {
    this.bid = props.bid();
    this.runtimeEnabled = runtimeEnabled;
  }

  @Bean
  public NewTopic bidsTopic() {
    return TopicBuilder.name(bid.topic())
        .partitions(bid.topicPartitions())
        .replicas(bid.topicReplication())
        .config("retention.ms", String.valueOf(7L * 24 * 3600 * 1000))
        .build();
  }

  /** DLT нь үндсэн topic-той ижил partition тоотой (recoverer ижил partition руу бичдэг). */
  @Bean
  public NewTopic bidsDeadLetterTopic() {
    return TopicBuilder.name(bid.topic() + DLT_SUFFIX)
        .partitions(bid.topicPartitions())
        .replicas(bid.topicReplication())
        .config("retention.ms", String.valueOf(30L * 24 * 3600 * 1000))
        .build();
  }

  // ---------- Producer ----------

  @Bean
  public KafkaTemplate<String, BidCommand> bidTemplate(
      KafkaProperties kafka, ObjectProvider<SslBundles> ssl, MeterRegistry meters) {
    Map<String, Object> cfg = new HashMap<>(kafka.buildProducerProperties(ssl.getIfAvailable()));
    cfg.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    cfg.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
    cfg.put(JsonSerializer.ADD_TYPE_INFO_HEADERS, false);
    DefaultKafkaProducerFactory<String, BidCommand> pf = new DefaultKafkaProducerFactory<>(cfg);
    pf.addListener(new MicrometerProducerListener<>(meters));
    return new KafkaTemplate<>(pf);
  }

  /** DLT руу deserialize хийж чадаагүй (byte[]) болон энгийн message-ийг хоёуланг нь бичнэ. */
  private DeadLetterPublishingRecoverer recoverer(KafkaProperties kafka, SslBundles ssl) {
    Map<String, Object> json = new HashMap<>(kafka.buildProducerProperties(ssl));
    json.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    json.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
    json.put(JsonSerializer.ADD_TYPE_INFO_HEADERS, false);
    Map<String, Object> bytes = new HashMap<>(kafka.buildProducerProperties(ssl));
    bytes.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
    bytes.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, ByteArraySerializer.class);

    Map<Class<?>, org.springframework.kafka.core.KafkaOperations<?, ?>> templates = new LinkedHashMap<>();
    templates.put(byte[].class, new KafkaTemplate<>(new DefaultKafkaProducerFactory<String, byte[]>(bytes)));
    templates.put(Object.class, new KafkaTemplate<>(new DefaultKafkaProducerFactory<String, Object>(json)));
    return new DeadLetterPublishingRecoverer(
        templates, (record, ex) -> new org.apache.kafka.common.TopicPartition(record.topic() + DLT_SUFFIX, record.partition()));
  }

  // ---------- Consumer ----------

  @Bean
  public ConsumerFactory<String, BidCommand> bidConsumerFactory(
      KafkaProperties kafka, ObjectProvider<SslBundles> ssl, MeterRegistry meters) {
    Map<String, Object> cfg = new HashMap<>(kafka.buildConsumerProperties(ssl.getIfAvailable()));
    cfg.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class);
    cfg.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, ErrorHandlingDeserializer.class);
    cfg.put(ErrorHandlingDeserializer.VALUE_DESERIALIZER_CLASS, JsonDeserializer.class);
    cfg.put(JsonDeserializer.VALUE_DEFAULT_TYPE, BidCommand.class.getName());
    cfg.put(JsonDeserializer.USE_TYPE_INFO_HEADERS, false);
    cfg.put(JsonDeserializer.TRUSTED_PACKAGES, "mn.eduud.auctions");
    DefaultKafkaConsumerFactory<String, BidCommand> cf = new DefaultKafkaConsumerFactory<>(cfg);
    cf.addListener(new MicrometerConsumerListener<>(meters));
    return cf;
  }

  @Bean
  public ConcurrentKafkaListenerContainerFactory<String, BidCommand> bidListenerFactory(
      ConsumerFactory<String, BidCommand> bidConsumerFactory, KafkaProperties kafka, ObjectProvider<SslBundles> ssl) {
    var factory = new ConcurrentKafkaListenerContainerFactory<String, BidCommand>();
    factory.setConsumerFactory(bidConsumerFactory);
    factory.setBatchListener(true);
    factory.setAutoStartup(runtimeEnabled);
    factory.setConcurrency(bid.consumerConcurrency());
    factory.getContainerProperties().setObservationEnabled(false);
    factory.getContainerProperties().setMicrometerEnabled(true);

    // 1с, 4с, 16с — дараа нь DLT
    ExponentialBackOffWithMaxRetries backOff = new ExponentialBackOffWithMaxRetries(3);
    backOff.setInitialInterval(1000L);
    backOff.setMultiplier(4.0);
    backOff.setMaxInterval(16000L);
    factory.setCommonErrorHandler(new DefaultErrorHandler(recoverer(kafka, ssl.getIfAvailable()), backOff));
    return factory;
  }

  /** Finalize-ийн өмнө partition-ийн lag шалгахад ашиглана. */
  @Bean(destroyMethod = "close")
  public AdminClient kafkaAdminClient(KafkaAdmin admin) {
    return AdminClient.create(admin.getConfigurationProperties());
  }
}
