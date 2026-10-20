import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';

/// Серверийн орчны төлөв. Тест горимын товч/самбарууд зөвхөн эндээс
/// баталгаажсан үед л харагдана — апп дотор hardcode хийхгүй.
class ServerConfig {
  const ServerConfig({this.otpTestMode = false, this.paymentTestMode = false});

  /// SMS жинхэнээсээ илгээгддэггүй — код нь хариунд ирнэ.
  final bool otpTestMode;

  /// Төлбөрийг гараар "төлөгдсөн" болгож симуляци хийж болно.
  final bool paymentTestMode;

  factory ServerConfig.fromJson(Map<String, dynamic> j) => ServerConfig(
        otpTestMode: (j['otpTestMode'] ?? false) as bool,
        paymentTestMode: (j['paymentTestMode'] ?? false) as bool,
      );
}

/// Сервер холбогдоогүй үед ч дэлгэц эвдрэхгүйн тулд алдааг залгиж, тест
/// горимыг унтраасан гэж үзнэ.
final serverConfigProvider = FutureProvider<ServerConfig>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/config');
    return ServerConfig.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return const ServerConfig();
  }
});
