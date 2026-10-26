package mn.eduud.seed;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import mn.eduud.common.auth.PasswordHasher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

/**
 * Seed (NestJS-ийн prisma/seed.ts + scripts/seed-loadtest.ts).
 *
 * <pre>
 *   java -jar app.jar --seed                         # багц, админ, контент
 *   java -jar app.jar --seed-loadtest --users=500 --tokens=1000 --auctions=10
 * </pre>
 * Seed хийгээд програм зогсоно.
 */
@Component
public class SeedRunner implements ApplicationRunner {
  private static final Logger log = LoggerFactory.getLogger(SeedRunner.class);
  public static final String LOADTEST_PASSWORD = "loadtest123";

  private final JdbcClient db;
  private final JdbcTemplate jdbc;
  private final PasswordHasher hasher;
  private final ApplicationContext ctx;

  public SeedRunner(JdbcClient db, JdbcTemplate jdbc, PasswordHasher hasher, ApplicationContext ctx) {
    this.db = db;
    this.jdbc = jdbc;
    this.hasher = hasher;
    this.ctx = ctx;
  }

  @Override
  public void run(ApplicationArguments args) {
    boolean seed = args.containsOption("seed");
    boolean loadtest = args.containsOption("seed-loadtest");
    if (!seed && !loadtest) return;
    if (seed) seedBase();
    if (loadtest) {
      seedLoadTest(intOpt(args, "users", 50), intOpt(args, "tokens", 20), intOpt(args, "auctions", 1));
    }
    System.exit(SpringApplication.exit(ctx, () -> 0));
  }

  private static int intOpt(ApplicationArguments args, String name, int def) {
    List<String> v = args.getOptionValues(name);
    return v == null || v.isEmpty() ? def : Integer.parseInt(v.get(0));
  }

  private void seedBase() {
    int[][] packages = {{15, 15000, 1}, {30, 24000, 2}, {50, 35000, 3}, {100, 65000, 4}};
    for (int[] p : packages) {
      int exists = db.sql("SELECT count(*) FROM token_packages WHERE tokens = ?").param(p[0]).query(Integer.class).single();
      if (exists == 0) {
        db.sql("INSERT INTO token_packages (id, tokens, price_mnt, sort_order) VALUES (?, ?, ?, ?)")
            .params(Ids.uuid(), p[0], p[1], p[2])
            .update();
      }
    }

    String adminPhone = env("SEED_ADMIN_PHONE", "99000000");
    String adminPassword = env("SEED_ADMIN_PASSWORD", "admin1234");
    String adminId =
        db.sql("SELECT id FROM users WHERE phone = ?").param(adminPhone).query(String.class).optional().orElse(null);
    if (adminId == null) {
      adminId = Ids.uuid();
      db.sql("INSERT INTO users (id, phone, name, password_hash, role, updated_at) VALUES (?, ?, 'Админ', ?, 'admin', now())")
          .params(adminId, adminPhone, hasher.hash(adminPassword))
          .update();
      db.sql("INSERT INTO wallets (user_id, balance, updated_at) VALUES (?, 0, now())").param(adminId).update();
    } else {
      db.sql("UPDATE users SET role = 'admin', updated_at = now() WHERE id = ?").param(adminId).update();
    }

    String[][] contents = {
      {"terms", "Үйлчилгээний нөхцөл", "Энд үйлчилгээний нөхцөлөө оруулна уу."},
      {"privacy", "Нууцлалын бодлого", "Энд нууцлалын бодлогоо оруулна уу."},
      {"faq", "Түгээмэл асуулт", "Энд түгээмэл асуулт хариултаа оруулна уу."},
    };
    for (String[] c : contents) {
      db.sql("INSERT INTO app_content (key, title, body, updated_at) VALUES (?, ?, ?, now()) ON CONFLICT (key) DO NOTHING")
          .params(c[0], c[1], c[2])
          .update();
    }
    log.info("Seed дууслаа. Админ: {} / {}", adminPhone, adminPassword);
  }

  /**
   * Load test-ийн бэлтгэл: N туршилтын хэрэглэгч (утас 90100000+i, нууц үг loadtest123),
   * тус бүр `tokens` token + K live auction. Auction-уудын id-г хэвлэнэ.
   */
  private void seedLoadTest(int users, int tokens, int auctions) {
    String adminId =
        db.sql("SELECT id FROM users WHERE role = 'admin' LIMIT 1")
            .query(String.class)
            .optional()
            .orElseThrow(() -> new IllegalStateException("Эхлээд --seed ажиллуулна уу (админ хэрэгтэй)."));

    // Argon2 удаан тул нэг hash-ийг бүх туршилтын хэрэглэгчид ашиглана
    String hash = hasher.hash(LOADTEST_PASSWORD);
    List<Object[]> userRows = new ArrayList<>();
    List<Object[]> walletRows = new ArrayList<>();
    for (int i = 0; i < users; i++) {
      String phone = "90" + (100000 + i);
      String id =
          db.sql("SELECT id FROM users WHERE phone = ?").param(phone).query(String.class).optional().orElse(null);
      if (id == null) {
        id = Ids.uuid();
        userRows.add(new Object[] {id, phone, "LoadTest " + i, hash});
      }
      walletRows.add(new Object[] {id, tokens, tokens});
    }
    jdbc.batchUpdate(
        "INSERT INTO users (id, phone, name, password_hash, updated_at) VALUES (?, ?, ?, ?, now())", userRows);
    jdbc.batchUpdate(
        "INSERT INTO wallets (user_id, balance, updated_at) VALUES (?, ?, now())"
            + " ON CONFLICT (user_id) DO UPDATE SET balance = ?, updated_at = now()",
        walletRows);

    Instant now = Instant.now();
    List<String> ids = new ArrayList<>();
    for (int k = 0; k < auctions; k++) {
      String id = Ids.uuid();
      db.sql(
              "INSERT INTO auctions (id, title, description, images, start_price, increment, soft_close_sec, extend_sec,"
                  + " starts_at, ends_at, current_price, status, created_by, updated_at)"
                  + " VALUES (?, ?, 'Зэрэгцээ саналын атомик байдлын туршилт', '{}', 1000, 10, 30, 30, ?, ?, 1000,"
                  + " 'live', ?, now())")
          .params(
              id,
              "Load test auction " + (k + 1) + " " + now,
              Rows.ts(now.minusSeconds(60)),
              Rows.ts(now.plusSeconds(3600)),
              adminId)
          .update();
      ids.add(id);
    }
    log.info("Load test: {} хэрэглэгч ({} token), нууц үг {}", users, tokens, LOADTEST_PASSWORD);
    System.out.println("LOADTEST_AUCTION_IDS=" + String.join(",", ids));
    System.out.println("LOADTEST_INFO=" + Map.of("users", users, "phonePrefix", "90", "firstPhone", "90100000"));
  }

  private static String env(String key, String def) {
    String v = System.getenv(key);
    return v == null || v.isEmpty() ? def : v;
  }
}
