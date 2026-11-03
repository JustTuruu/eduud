import 'package:flutter/foundation.dart' show kIsWeb;

/// Орчны тохиргоо.
/// Бодит төхөөрөмж дээр туршихдаа компьютерийнхаа LAN IP-г тавина
/// (жиш. http://192.168.1.10:3000). Android emulator: http://10.0.2.2:3000.
/// Web (Chrome) дээр backend ижил компьютер дээр ажиллаж байвал localhost.
abstract class AppConfig {
  static const _explicitApi = String.fromEnvironment('API_URL');

  static String get apiBaseUrl {
    if (_explicitApi.isNotEmpty) return _explicitApi;
    return kIsWeb ? 'http://localhost:3000' : 'http://10.0.2.2:3000';
  }

  /// Socket.IO сервер (Spring backend-д тусдаа порт 3001).
  /// --dart-define=SOCKET_URL=... өгөөгүй бол API_URL-ийн портыг 3001 болгоно.
  static String get socketUrl {
    const explicit = String.fromEnvironment('SOCKET_URL');
    if (explicit.isNotEmpty) return explicit;
    final api = Uri.parse(apiBaseUrl);
    return api.replace(port: 3001).toString();
  }
}
