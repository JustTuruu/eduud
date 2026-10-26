package mn.eduud.config;

import java.util.List;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthInterceptor;
import mn.eduud.common.auth.AuthUser;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.MethodParameter;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {
  private final AuthInterceptor authInterceptor;

  public WebConfig(AuthInterceptor authInterceptor) {
    this.authInterceptor = authInterceptor;
  }

  @Override
  public void addInterceptors(InterceptorRegistry registry) {
    registry.addInterceptor(authInterceptor).excludePathPatterns("/actuator/**", "/error");
  }

  @Override
  public void addCorsMappings(CorsRegistry registry) {
    // NestJS: app.enableCors({ origin: true })
    registry.addMapping("/**").allowedOriginPatterns("*").allowedMethods("*").allowedHeaders("*");
  }

  @Override
  public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
    resolvers.add(
        new HandlerMethodArgumentResolver() {
          @Override
          public boolean supportsParameter(MethodParameter p) {
            return p.hasParameterAnnotation(CurrentUser.class) && p.getParameterType() == AuthUser.class;
          }

          @Override
          public Object resolveArgument(
              MethodParameter p, ModelAndViewContainer mav, NativeWebRequest req, WebDataBinderFactory f) {
            return req.getAttribute(AuthInterceptor.ATTR, RequestAttributes.SCOPE_REQUEST);
          }
        });
  }
}
