package mn.eduud.media;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.net.URI;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.auth.AuthAnnotations.CurrentUser;
import mn.eduud.common.auth.AuthUser;
import mn.eduud.config.AppProperties;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;

/** Cloudflare R2 (S3-compatible) — Flutter шууд upload хийх presigned PUT URL (5 мин). */
@RestController
@RequestMapping("/media")
public class MediaController {
  private static final List<String> ALLOWED_TYPES = List.of("image/jpeg", "image/png", "image/webp");

  private final AppProperties.R2 r2;
  private volatile S3Presigner presigner;

  public MediaController(AppProperties props) {
    this.r2 = props.r2();
  }

  public record PresignDto(
      @NotNull @Pattern(regexp = "^(avatar|auction)$", message = "kind must be one of: avatar, auction") String kind,
      @NotNull String contentType) {}

  @PostMapping("/presign")
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> presign(@CurrentUser AuthUser user, @Valid @RequestBody PresignDto dto) {
    if (!ALLOWED_TYPES.contains(dto.contentType())) {
      throw ApiException.badRequest("Зөвхөн JPEG/PNG/WebP зураг зөвшөөрнө.");
    }
    if ("auction".equals(dto.kind()) && !user.isAdmin()) throw ApiException.forbidden("Хандах эрхгүй");

    String prefix = "avatar".equals(dto.kind()) ? "avatars" : "auctions";
    String ext = dto.contentType().substring(dto.contentType().indexOf('/') + 1);
    String key = prefix + "/" + Ids.uuid() + "." + ext;
    String uploadUrl =
        presigner()
            .presignPutObject(
                PutObjectPresignRequest.builder()
                    .signatureDuration(Duration.ofSeconds(300))
                    .putObjectRequest(
                        PutObjectRequest.builder().bucket(r2.bucket()).key(key).contentType(dto.contentType()).build())
                    .build())
            .url()
            .toString();
    return Map.of("uploadUrl", uploadUrl, "key", key, "publicUrl", r2.publicUrl() + "/" + key);
  }

  private S3Presigner presigner() {
    if (presigner == null) {
      synchronized (this) {
        if (presigner == null) {
          presigner =
              S3Presigner.builder()
                  .region(Region.of("auto"))
                  .endpointOverride(URI.create("https://" + r2.accountId() + ".r2.cloudflarestorage.com"))
                  .credentialsProvider(
                      StaticCredentialsProvider.create(
                          AwsBasicCredentials.create(nz(r2.accessKeyId()), nz(r2.secretAccessKey()))))
                  .serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(true).build())
                  .build();
        }
      }
    }
    return presigner;
  }

  private static String nz(String s) {
    return s == null || s.isEmpty() ? "unset" : s;
  }
}
