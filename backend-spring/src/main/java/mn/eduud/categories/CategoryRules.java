package mn.eduud.categories;

import mn.eduud.common.ApiException;

/** Ангилалын цэвэр дүрэм (DB-ээс хараат бус). */
public final class CategoryRules {
  public static final int MAX_NAME = 40;

  private CategoryRules() {}

  /** Нэрийг trim хийж 1..40 тэмдэгт эсэхийг шалгана. */
  public static String validateName(String raw) {
    String name = raw == null ? "" : raw.trim();
    if (name.isEmpty() || name.length() > MAX_NAME) {
      throw ApiException.badRequest("Ангилалын нэр 1–" + MAX_NAME + " тэмдэгт байх ёстой.");
    }
    return name;
  }
}
