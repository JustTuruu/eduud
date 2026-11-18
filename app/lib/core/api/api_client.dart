import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../storage/token_storage.dart';

/// Token хадгалалт — платформ бүрт тохирсон backend ([token_storage.dart]).
class TokenStore {
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  Future<String?> get access => storageRead(_kAccess);
  Future<String?> get refresh => storageRead(_kRefresh);

  Future<void> save(String access, String refresh) async {
    await storageWrite(_kAccess, access);
    await storageWrite(_kRefresh, refresh);
  }

  Future<void> clear() async {
    await storageDelete(_kAccess);
    await storageDelete(_kRefresh);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// Backend-ийн алдааны message-ийг хэрэглэгчид ойлгомжтойгоор гаргана.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));
  final store = ref.watch(tokenStoreProvider);

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await store.access;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (err, handler) async {
      // 401 үед refresh хийгээд нэг удаа дахин оролдоно
      if (err.response?.statusCode == 401 &&
          err.requestOptions.extra['retried'] != true &&
          !err.requestOptions.path.startsWith('/auth/')) {
        final refresh = await store.refresh;
        if (refresh != null) {
          try {
            final res = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
                .post('/auth/refresh', data: {'refreshToken': refresh});
            final data = res.data as Map<String, dynamic>;
            await store.save(
                data['accessToken'] as String, data['refreshToken'] as String);
            final opts = err.requestOptions;
            opts.extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer ${data['accessToken']}';
            final retried = await dio.fetch(opts);
            return handler.resolve(retried);
          } catch (_) {
            await store.clear();
          }
        }
      }
      handler.next(err);
    },
  ));
  return dio;
});

/// DioException-ээс монгол message салгана.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final msg = data['message'];
      if (msg is List) return msg.join('\n');
      return msg.toString();
    }
    if (error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Хариу удаан байна. Дахин оролдоно уу.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Холболт тасарлаа. Дахин оролдоно уу.';
    }
  }
  return 'Алдаа гарлаа. Дахин оролдоно уу.';
}
