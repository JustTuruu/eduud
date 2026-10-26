package mn.eduud.common.auth;

import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Arrays;
import mn.eduud.common.ApiException;
import mn.eduud.common.auth.AuthAnnotations.Public;
import mn.eduud.common.auth.AuthAnnotations.Roles;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * NestJS-ийн JwtAuthGuard + RolesGuard: бүх route анхдагчаар нэвтрэлт шаардана,
 * @Public тавьсан нь чөлөөтэй, @Roles нь ролийг шалгана.
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {
  public static final String ATTR = "authUser";
  private final JwtService jwt;

  public AuthInterceptor(JwtService jwt) {
    this.jwt = jwt;
  }

  @Override
  public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
    if (!(handler instanceof HandlerMethod hm)) return true;

    boolean isPublic =
        AnnotatedElementUtils.hasAnnotation(hm.getMethod(), Public.class)
            || AnnotatedElementUtils.hasAnnotation(hm.getBeanType(), Public.class);
    if (isPublic) return true;

    String header = req.getHeader("Authorization");
    String token = header != null && header.startsWith("Bearer ") ? header.substring(7) : null;
    if (token == null) throw ApiException.unauthorized("Нэвтрэх шаардлагатай");

    AuthUser user;
    try {
      Claims c = jwt.verify(token);
      if (c.getSubject() == null) throw new IllegalStateException();
      user = new AuthUser(c.getSubject(), String.valueOf(c.get("role")));
    } catch (Exception e) {
      throw ApiException.unauthorized("Токен хүчингүй эсвэл хугацаа дууссан");
    }
    req.setAttribute(ATTR, user);

    Roles roles = AnnotatedElementUtils.findMergedAnnotation(hm.getMethod(), Roles.class);
    if (roles == null) roles = AnnotatedElementUtils.findMergedAnnotation(hm.getBeanType(), Roles.class);
    if (roles != null && Arrays.stream(roles.value()).noneMatch(r -> r.equals(user.role()))) {
      throw ApiException.forbidden("Хандах эрхгүй");
    }
    return true;
  }
}
