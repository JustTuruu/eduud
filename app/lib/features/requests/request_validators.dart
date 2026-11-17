/// Зохион байгуулах хүсэлтийн талбарын шалгалт — цэвэр функцууд.
abstract class RequestValidators {
  static String? title(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Барааны нэрийг бичнэ үү';
    if (v.length < 3) return 'Дор хаяж 3 тэмдэгт бичнэ үү';
    if (v.length > 120) return '120 тэмдэгтээс хэтэрсэн байна';
    return null;
  }

  static String? description(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Тайлбарыг бичнэ үү';
    if (v.length < 10) return 'Дор хаяж 10 тэмдэгт бичнэ үү';
    if (v.length > 4000) return '4000 тэмдэгтээс хэтэрсэн байна';
    return null;
  }

  /// Хоосон байж болно; бөглөсөн бол 0 буюу түүнээс их бүхэл тоо.
  static String? startPrice(String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final n = int.tryParse(v);
    if (n == null) return 'Бүхэл тоо оруулна уу';
    if (n < 0) return 'Үнэ сөрөг байж болохгүй';
    return null;
  }
}
