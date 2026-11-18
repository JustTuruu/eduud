package mn.eduud.categories;

import java.util.List;
import java.util.Map;
import mn.eduud.common.auth.AuthAnnotations.Public;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class CategoriesController {
  private final CategoriesService categories;

  public CategoriesController(CategoriesService categories) {
    this.categories = categories;
  }

  @Public
  @GetMapping("/categories")
  public List<Map<String, Object>> list() {
    return categories.listPublic();
  }
}
