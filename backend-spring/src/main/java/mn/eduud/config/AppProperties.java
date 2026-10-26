package mn.eduud.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(
    Jwt jwt,
    Otp otp,
    Wire wire,
    R2 r2,
    Socket socket,
    Orders orders,
    Bid bid,
    Scheduler scheduler) {

  public record Jwt(String accessSecret, String refreshSecret, long accessTtlSec, long refreshTtlSec) {}

  public record Otp(String provider, String verifymnApiUrl, String verifymnApiKey) {
    public boolean isMock() {
      return !"verifymn".equals(provider);
    }
  }

  public record Wire(String mode, String apiUrl, String apiKey, String webhookSecret) {
    public boolean isTest() {
      return !"live".equals(mode);
    }
  }

  public record R2(String accountId, String accessKeyId, String secretAccessKey, String bucket, String publicUrl) {}

  public record Socket(int port) {}

  public record Orders(int payDeadlineHours) {}

  public record Bid(
      String mode,
      String topic,
      int topicPartitions,
      int topicReplication,
      int consumerConcurrency,
      long produceTimeoutMs) {
    public boolean isKafka() {
      return "kafka".equalsIgnoreCase(mode);
    }
  }

  public record Scheduler(long tickMs, long maxFinalizeWaitMs) {}
}
