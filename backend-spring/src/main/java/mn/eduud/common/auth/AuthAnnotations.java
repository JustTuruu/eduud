package mn.eduud.common.auth;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** NestJS-ийн @Public / @Roles / @CurrentUser decorator-уудын Java хувилбар. */
public final class AuthAnnotations {
  private AuthAnnotations() {}

  /** Нэвтрэлтгүйгээр хандаж болно. */
  @Retention(RetentionPolicy.RUNTIME)
  @Target({ElementType.TYPE, ElementType.METHOD})
  public @interface Public {}

  /** Зөвхөн заасан ролиуд хандана (жиш. "admin"). */
  @Retention(RetentionPolicy.RUNTIME)
  @Target({ElementType.TYPE, ElementType.METHOD})
  public @interface Roles {
    String[] value();
  }

  /** Controller-ийн параметрт нэвтэрсэн хэрэглэгчийг (AuthUser) оруулна. */
  @Retention(RetentionPolicy.RUNTIME)
  @Target(ElementType.PARAMETER)
  public @interface CurrentUser {}
}
