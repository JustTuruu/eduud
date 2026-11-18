package mn.eduud.categories;

import java.util.List;
import java.util.Map;
import mn.eduud.common.ApiException;
import mn.eduud.common.Ids;
import mn.eduud.common.Rows;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class CategoriesService {
  private static final String DUPLICATE = "Ийм ангилал аль хэдийн байна";

  private final JdbcClient db;
  private final Rows rows;

  public CategoriesService(JdbcClient db, Rows rows) {
    this.db = db;
    this.rows = rows;
  }

  public List<Map<String, Object>> listPublic() {
    return db.sql("SELECT id, name, sort_order FROM categories WHERE active ORDER BY sort_order, name")
        .query(rows.camel())
        .list();
  }

  public List<Map<String, Object>> listAdmin() {
    return db.sql(
            "SELECT c.id, c.name, c.sort_order, c.active,"
                + " (SELECT count(*) FROM auctions a WHERE a.category_id = c.id)::int AS auction_count"
                + " FROM categories c ORDER BY c.sort_order, c.name")
        .query(rows.camel())
        .list();
  }

  public Map<String, Object> create(String rawName, Integer sortOrder) {
    String name = CategoryRules.validateName(rawName);
    String id = Ids.uuid();
    try {
      db.sql("INSERT INTO categories (id, name, sort_order) VALUES (?, ?, ?)")
          .params(id, name, sortOrder == null ? 0 : sortOrder)
          .update();
    } catch (DuplicateKeyException e) {
      throw ApiException.conflict(DUPLICATE);
    }
    return adminRow(id);
  }

  public Map<String, Object> update(String id, String rawName, Integer sortOrder, Boolean active) {
    String name = rawName == null ? null : CategoryRules.validateName(rawName);
    int n;
    try {
      n =
          db.sql(
                  "UPDATE categories SET name = COALESCE(?, name), sort_order = COALESCE(?, sort_order),"
                      + " active = COALESCE(?, active), updated_at = now() WHERE id = ?")
              .params(name, sortOrder, active, id)
              .update();
    } catch (DuplicateKeyException e) {
      throw ApiException.conflict(DUPLICATE);
    }
    if (n == 0) throw ApiException.notFound("Ангилал олдсонгүй");
    return adminRow(id);
  }

  public void delete(String id) {
    Integer used = db.sql("SELECT count(*)::int FROM auctions WHERE category_id = ?").param(id).query(Integer.class).single();
    if (used > 0) {
      throw ApiException.conflict("Энэ ангилалд дуудлага худалдаа байгаа тул устгах боломжгүй. Идэвхгүй болгоно уу.");
    }
    int n = db.sql("DELETE FROM categories WHERE id = ?").param(id).update();
    if (n == 0) throw ApiException.notFound("Ангилал олдсонгүй");
  }

  /** categoryId байгаа эсэхийг шалгана (null бол юу ч хийхгүй). */
  public void requireExists(String id) {
    if (id == null) return;
    Integer n = db.sql("SELECT count(*)::int FROM categories WHERE id = ?").param(id).query(Integer.class).single();
    if (n == 0) throw ApiException.badRequest("Ангилал олдсонгүй");
  }

  private Map<String, Object> adminRow(String id) {
    return db.sql(
            "SELECT c.id, c.name, c.sort_order, c.active,"
                + " (SELECT count(*) FROM auctions a WHERE a.category_id = c.id)::int AS auction_count"
                + " FROM categories c WHERE c.id = ?")
        .param(id)
        .query(rows.camel())
        .single();
  }
}
