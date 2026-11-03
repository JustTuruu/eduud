/// Access/refresh token-ийг платформд тохирсон аргаар хадгална:
/// - mobile: flutter_secure_storage (Keychain / EncryptedSharedPreferences)
/// - web: localStorage (secure storage web дээр WebCrypto шаарддаг тул
///   `http://<LAN-IP>` гэх мэт secure context биш орчинд унадаг)
library;
export 'token_storage_io.dart' if (dart.library.js_interop) 'token_storage_web.dart';
