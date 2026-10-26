package mn.eduud.common;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import java.util.HexFormat;
import java.util.UUID;

public final class Ids {
  private static final SecureRandom RANDOM = new SecureRandom();

  private Ids() {}

  public static String uuid() {
    return UUID.randomUUID().toString();
  }

  public static String sha256Hex(String value) {
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(md.digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }

  /** Node-ийн randomBytes(n).toString('base64url')-тэй адил. */
  public static String randomBase64Url(int bytes) {
    byte[] b = new byte[bytes];
    RANDOM.nextBytes(b);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
  }

  /** [min, max) хооронд санамсаргүй бүхэл тоо. */
  public static int randomInt(int min, int max) {
    return min + RANDOM.nextInt(max - min);
  }
}
