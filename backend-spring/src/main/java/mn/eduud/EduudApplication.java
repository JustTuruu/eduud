package mn.eduud;

import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@ConfigurationPropertiesScan
@EnableScheduling
public class EduudApplication {

  public static void main(String[] args) {
    // DB-ийн TIMESTAMP(3) багана нь timezone-гүй, Prisma UTC-ээр бичдэг.
    // JVM-ийг UTC болгосноор Timestamp <-> Instant хөрвүүлэлт зөв явна.
    TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
    // Seed горимд зөвхөн DB-д бичээд гарна: вэб сервер, consumer, socket, scheduler асаахгүй
    for (String a : args) {
      if (a.startsWith("--seed")) {
        System.setProperty("spring.main.web-application-type", "none");
        System.setProperty("app.runtime-enabled", "false");
      }
    }
    SpringApplication.run(EduudApplication.class, args);
  }
}
