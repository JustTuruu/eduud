/// Орчны тохиргоо.
/// Бодит төхөөрөмж дээр туршихдаа компьютерийнхаа LAN IP-г тавина
/// (жиш. http://192.168.1.10:3000). Android emulator: http://10.0.2.2:3000.
abstract class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  /// Socket.IO сервер (Spring backend-д тусдаа порт 3001).
  /// --dart-define=SOCKET_URL=... өгөөгүй бол API_URL-ийн портыг 3001 болгоно.
  static String get socketUrl {
    const explicit = String.fromEnvironment('SOCKET_URL');
    if (explicit.isNotEmpty) return explicit;
    final api = Uri.parse(apiBaseUrl);
    return api.replace(port: 3001).toString();
  }
}
