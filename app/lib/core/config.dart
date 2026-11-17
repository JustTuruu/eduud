import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Орчны тохиргоо.
///
/// Анхдагч хаяг (--dart-define=API_URL өгөөгүй үед):
/// - Web (Chrome): http://localhost:3000
/// - Android emulator: http://10.0.2.2:3000 (emulator-ийн host руу хандах хаяг)
/// - iOS simulator болон бусад: http://localhost:3000
///
/// Бодит утас дээр localhost ажиллахгүй — компьютерийнхээ LAN IP-г өгнө
/// (жиш. http://192.168.1.10:3000). Үүнийг `tool/run.sh` автоматаар хийнэ.
abstract class AppConfig {
  static const _explicitApi = String.fromEnvironment('API_URL');

  static String get apiBaseUrl {
    if (_explicitApi.isNotEmpty) return _explicitApi;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
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
