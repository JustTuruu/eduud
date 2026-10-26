package mn.eduud.common.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import javax.crypto.SecretKey;
import mn.eduud.config.AppProperties;
import org.springframework.stereotype.Service;

/**
 * HS256 JWT. NestJS (@nestjs/jwt)-ийн гаргасан токентой бүрэн нийцтэй:
 * ижил JWT_ACCESS_SECRET ашиглавал хоёр backend нэг нэгнийхээ токенийг хүлээн авна.
 */
@Service
public class JwtService {
  private final SecretKey accessKey;
  private final long accessTtlSec;

  public JwtService(AppProperties props) {
    this.accessKey = key(props.jwt().accessSecret());
    this.accessTtlSec = props.jwt().accessTtlSec();
  }

  /** HMAC түлхүүр. jjwt 256-битээс богино түлхүүрийг хүлээж авдаггүй тул NestJS-ийн
   *  богино secret-ийг ч ажиллуулахын тулд Keys.hmacShaKeyFor-ийг тойрно. */
  private static SecretKey key(String secret) {
    byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
    if (bytes.length >= 32) return Keys.hmacShaKeyFor(bytes);
    return new javax.crypto.spec.SecretKeySpec(bytes, "HmacSHA256");
  }

  public String signAccess(String userId, String role) {
    Instant now = Instant.now();
    return Jwts.builder()
        .claims(Map.of("sub", userId, "role", role))
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plusSeconds(accessTtlSec)))
        .signWith(accessKey, Jwts.SIG.HS256)
        .compact();
  }

  /** OTP-ийн дараах богино хугацааны ticket (register/reset). */
  public String signTicket(String phone, String purpose, Duration ttl) {
    Instant now = Instant.now();
    return Jwts.builder()
        .claims(Map.of("phone", phone, "purpose", purpose, "kind", "otp-ticket"))
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plus(ttl)))
        .signWith(accessKey, Jwts.SIG.HS256)
        .compact();
  }

  /** Хүчинтэй бол claim-уудыг, эсрэг тохиолдолд exception шиднэ. */
  public Claims verify(String token) {
    return Jwts.parser().verifyWith(accessKey).build().parseSignedClaims(token).getPayload();
  }
}
