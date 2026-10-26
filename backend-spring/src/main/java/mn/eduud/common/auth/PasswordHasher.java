package mn.eduud.common.auth;

import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Argon2id. node-argon2-ийн анхдагч параметртэй ижил (m=64MiB, t=3, p=4, salt 16, hash 32)
 * тул NestJS-ийн үүсгэсэн hash-ийг шалгаж, шинээр үүсгэсэн hash-ийг NestJS ч шалгаж чадна.
 */
@Component
public class PasswordHasher {
  private final Argon2PasswordEncoder encoder = new Argon2PasswordEncoder(16, 32, 4, 65536, 3);

  public String hash(String password) {
    return encoder.encode(password);
  }

  /** node-argon2 нь параметрийг `m=..,p=..,t=..` дарааллаар бичдэг; Spring `m,t,p`-г хүлээдэг. */
  private static final java.util.regex.Pattern NODE_PARAMS =
      java.util.regex.Pattern.compile("\\$m=(\\d+),p=(\\d+),t=(\\d+)\\$");

  public boolean verify(String hash, String password) {
    try {
      String normalized = NODE_PARAMS.matcher(hash).replaceFirst("\\$m=$1,t=$3,p=$2\\$");
      return encoder.matches(password, normalized);
    } catch (Exception e) {
      return false;
    }
  }
}
