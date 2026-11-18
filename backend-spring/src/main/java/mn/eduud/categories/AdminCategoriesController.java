package mn.eduud.categories;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import mn.eduud.common.auth.AuthAnnotations.Roles;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Roles("admin")
@RestController
@RequestMapping("/admin/categories")
public class AdminCategoriesController {
  public record CreateCategoryDto(String name, Integer sortOrder) {}

  public record UpdateCategoryDto(String name, Integer sortOrder, Boolean active) {}

  private final CategoriesService categories;

  public AdminCategoriesController(CategoriesService categories) {
    this.categories = categories;
  }

  @GetMapping
  public List<Map<String, Object>> list() {
    return categories.listAdmin();
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  public Map<String, Object> create(@RequestBody CreateCategoryDto dto) {
    return categories.create(dto.name(), dto.sortOrder());
  }

  @PatchMapping("/{id}")
  public Map<String, Object> update(@PathVariable UUID id, @RequestBody UpdateCategoryDto dto) {
    return categories.update(id.toString(), dto.name(), dto.sortOrder(), dto.active());
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  public void delete(@PathVariable UUID id) {
    categories.delete(id.toString());
  }
}
