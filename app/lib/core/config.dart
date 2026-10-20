/// Орчны тохиргоо.
/// Бодит төхөөрөмж дээр туршихдаа компьютерийнхаа LAN IP-г тавина
/// (жиш. http://192.168.1.10:3000). Android emulator: http://10.0.2.2:3000.
abstract class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
