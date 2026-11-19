package mn.eduud.auctions;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import mn.eduud.common.ApiException;

/** 2/3-р байрны шагналын цэвэр дүрэм (DB-ээс хараат бус). */
public final class PrizeRules {
  public static final int MAX_TOKENS = 100_000;
  public static final int MAX_TITLE = 120;

  private PrizeRules() {}

  /** Админаас ирсэн шагнал: kind = "tokens" | "item". */
  public record Prize(Integer place, String kind, Integer tokens, String title) {}

  /**
   * Жагсаалтыг шалгаж, хэвийн хэлбэрт (title trim, хамааралгүй талбар null, place-ээр эрэмбэлсэн)
   * оруулж буцаана. Алдаа гарвал 400.
   */
  public static List<Prize> validate(List<Prize> prizes) {
    List<Prize> out = new ArrayList<>();
    if (prizes == null) return out;
    Set<Integer> places = new HashSet<>();
    for (Prize p : prizes) {
      if (p == null || p.place() == null || (p.place() != 2 && p.place() != 3)) {
        throw ApiException.badRequest("Шагналын байр 2 эсвэл 3 байх ёстой.");
      }
      if (!places.add(p.place())) {
        throw ApiException.badRequest("Нэг байранд нэг шагнал л тохируулна.");
      }
      if ("tokens".equals(p.kind())) {
        if (p.tokens() == null || p.tokens() < 1 || p.tokens() > MAX_TOKENS) {
          throw ApiException.badRequest("Шагналын эрхийн тоо 1–" + MAX_TOKENS + " байх ёстой.");
        }
        out.add(new Prize(p.place(), "tokens", p.tokens(), null));
      } else if ("item".equals(p.kind())) {
        String title = p.title() == null ? "" : p.title().trim();
        if (title.isEmpty() || title.length() > MAX_TITLE) {
          throw ApiException.badRequest("Шагналын нэр 1–" + MAX_TITLE + " тэмдэгт байх ёстой.");
        }
        out.add(new Prize(p.place(), "item", null, title));
      } else {
        throw ApiException.badRequest("Шагналын төрөл 'tokens' эсвэл 'item' байх ёстой.");
      }
    }
    out.sort(Comparator.comparing(Prize::place));
    return out;
  }
}
