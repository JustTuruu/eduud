package mn.eduud.requests;

import java.util.List;
import java.util.Set;
import mn.eduud.common.ApiException;

/** Дуудлага худалдааны хүсэлтийн цэвэр дүрэм (DB-ээс хараат бус): шалгалт, төлөв шилжилт. */
public final class AuctionRequestRules {
  public static final int TITLE_MIN = 3;
  public static final int TITLE_MAX = 120;
  public static final int DESCRIPTION_MIN = 10;
  public static final int DESCRIPTION_MAX = 4000;
  public static final int OTHER_MAX = 1000;
  public static final long START_PRICE_MAX = 1_000_000_000L;

  public static final List<String> DECISION_STATUSES = List.of("reviewing", "approved", "rejected", "info_requested");
  public static final List<String> ALL_STATUSES =
      List.of("draft", "pending", "reviewing", "info_requested", "approved", "rejected", "cancelled");

  private static final Set<String> EDITABLE = Set.of("draft", "info_requested");
  private static final Set<String> CANCELLABLE = Set.of("draft", "pending", "info_requested");
  private static final Set<String> DECIDABLE = Set.of("pending", "reviewing", "info_requested");

  private AuctionRequestRules() {}

  /** Хоосон зайг тайрч, хоосон бол null буцаана. */
  public static String clean(String value) {
    if (value == null) {
      return null;
    }
    String t = value.trim();
    return t.isEmpty() ? null : t;
  }

  /** Гарчгийг шалгаж тайрсан утгыг буцаана. */
  public static String validateTitle(String title) {
    String t = clean(title);
    if (t == null || t.length() < TITLE_MIN || t.length() > TITLE_MAX) {
      throw ApiException.badRequest("Гарчиг " + TITLE_MIN + "-" + TITLE_MAX + " тэмдэгт байх ёстой.");
    }
    return t;
  }

  public static String validateDescription(String description) {
    String t = clean(description);
    if (t == null || t.length() < DESCRIPTION_MIN || t.length() > DESCRIPTION_MAX) {
      throw ApiException.badRequest(
          "Тайлбар " + DESCRIPTION_MIN + "-" + DESCRIPTION_MAX + " тэмдэгт байх ёстой.");
    }
    return t;
  }

  public static Integer validateStartPrice(Long startPrice) {
    if (startPrice == null) {
      return null;
    }
    if (startPrice < 0 || startPrice > START_PRICE_MAX) {
      throw ApiException.badRequest("Эхлэх үнэ 0-ээс " + START_PRICE_MAX + "₮ хооронд байх ёстой.");
    }
    return startPrice.intValue();
  }

  /** Заавал биш тэмдэгт талбар: тайрч, урт хэтэрвэл алдаа. */
  public static String validateOptional(String value, String label) {
    String t = clean(value);
    if (t != null && t.length() > OTHER_MAX) {
      throw ApiException.badRequest(label + " " + OTHER_MAX + " тэмдэгтээс хэтэрч болохгүй.");
    }
    return t;
  }

  public static String initialStatus(Boolean draft) {
    return Boolean.TRUE.equals(draft) ? "draft" : "pending";
  }

  public static boolean canEdit(String status) {
    return EDITABLE.contains(status);
  }

  public static boolean canCancel(String status) {
    return CANCELLABLE.contains(status);
  }

  public static boolean canDecide(String currentStatus) {
    return DECIDABLE.contains(currentStatus);
  }

  /** Засварлаж илгээхэд шинэ төлөв: submit бол pending, үгүй бол хэвээр. */
  public static String statusAfterEdit(String current, boolean submit) {
    return submit ? "pending" : current;
  }

  /** Админы шийдвэрийн шалгалт: төлөв зөвшөөрөгдсөн эсэх, татгалзах / мэдээлэл шаардах үед тэмдэглэл заавал. */
  public static String validateDecision(String status, String note) {
    if (status == null || !DECISION_STATUSES.contains(status)) {
      throw ApiException.badRequest("Шийдвэрийн төлөв буруу байна.");
    }
    String n = validateOptional(note, "Тэмдэглэл");
    if (("rejected".equals(status) || "info_requested".equals(status)) && n == null) {
      throw ApiException.badRequest("Татгалзах эсвэл нэмэлт мэдээлэл шаардахад тэмдэглэл заавал бичнэ.");
    }
    return n;
  }
}
