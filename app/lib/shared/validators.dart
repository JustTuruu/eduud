/// Маягтын баталгаажуулалт. Backend-ийн дүрэмтэй яг тааруулсан тул
/// хэрэглэгч сервер лүү явахаас өмнө алдаагаа мэднэ.
///
/// Backend: `PHONE_REGEX = /^[6-9]\d{7}$/`, нууц үг 8..72 тэмдэгт, нэр 2..30.
library;

abstract class Validators {
  /// Монгол гар утас: 8 орон, 6/7/8/9-өөр эхэлнэ.
  static final phoneRegex = RegExp(r'^[6-9]\d{7}$');

  static const phoneLength = 8;
  static const passwordMin = 8;
  static const passwordMax = 72;
  static const nameMin = 2;
  static const nameMax = 30;
  static const otpLength = 6;

  /// null = алдаагүй.
  static String? phone(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Утасны дугаараа оруулна уу';
    if (v.length < phoneLength) return 'Утасны дугаар 8 оронтой байна';
    if (!phoneRegex.hasMatch(v)) return 'Дугаар 6, 7, 8 эсвэл 9-өөр эхэлнэ';
    return null;
  }

  static String? password(String value) {
    if (value.isEmpty) return 'Нууц үгээ оруулна уу';
    if (value.length < passwordMin) return 'Нууц үг доод тал нь 8 тэмдэгт байна';
    if (value.length > passwordMax) return 'Нууц үг хэт урт байна';
    return null;
  }

  /// Нэвтрэх үед нууц үгийн уртыг шалгахгүй — хуучин бүртгэлүүд ч нэвтэрч
  /// чадах ёстой, зөвхөн хоосон эсэхийг л шалгана.
  static String? loginPassword(String value) {
    if (value.isEmpty) return 'Нууц үгээ оруулна уу';
    return null;
  }

  static String? confirmPassword(String value, String original) {
    if (value.isEmpty) return 'Нууц үгээ давтан оруулна уу';
    if (value != original) return 'Нууц үг таарахгүй байна';
    return null;
  }

  static String? name(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Нэрээ оруулна уу';
    if (v.length < nameMin) return 'Нэр доод тал нь 2 тэмдэгт байна';
    if (v.length > nameMax) return 'Нэр 30 тэмдэгтээс хэтрэхгүй';
    return null;
  }

  static String? otp(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Баталгаажуулах кодоо оруулна уу';
    if (v.length < otpLength) return 'Код 6 оронтой байна';
    return null;
  }

  static String? feedbackMessage(String value) {
    final v = value.trim();
    if (v.isEmpty) return 'Дэлгэрэнгүй бичнэ үү';
    if (v.length < 10) return 'Дор хаяж 10 тэмдэгт бичнэ үү';
    if (v.length > 2000) return '2000 тэмдэгтээс хэтэрсэн байна';
    return null;
  }
}

/// Нууц үгийн бат бөх байдал: 0 = хоосон, 1 = сул … 4 = хүчтэй.
class PasswordStrength {
  const PasswordStrength(this.level, this.label, this.hint);

  final int level;
  final String label;

  /// Дараагийн шатанд хүрэхийн тулд юу хийх вэ.
  final String hint;

  static const _empty = PasswordStrength(0, '', '');

  bool get isEmpty => level == 0;

  static PasswordStrength of(String p) {
    if (p.isEmpty) return _empty;

    final hasLower = RegExp(r'[a-z]').hasMatch(p);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
    final hasDigit = RegExp(r'\d').hasMatch(p);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(p);

    var points = 0;
    if (p.length >= 6) points += 1;
    if (p.length >= 8) points += 1;
    if (p.length >= 12) points += 1;
    if (hasLower && hasUpper) points += 1;
    if (hasDigit) points += 1;
    if (hasSymbol) points += 1;

    // 8 тэмдэгтэд хүрээгүй бол хэчнээн төрөлжсөн ч "сул" хэвээр — backend
    // хүлээж авахгүй тул хэрэглэгчийг төөрөгдүүлэхгүй.
    if (p.length < 8) {
      return PasswordStrength(1, 'Сул', 'Дор хаяж 8 тэмдэгт болгоно уу');
    }

    if (points <= 2) {
      return const PasswordStrength(1, 'Сул', 'Урт болгож, тоо нэмнэ үү');
    }
    if (points == 3) {
      return const PasswordStrength(2, 'Дунд', 'Том үсэг эсвэл тоо нэмнэ үү');
    }
    if (points == 4) {
      return const PasswordStrength(3, 'Сайн', 'Тэмдэгт (!, @, #) нэмбэл хүчтэй болно');
    }
    return const PasswordStrength(4, 'Хүчтэй', 'Сайн нууц үг байна');
  }
}
