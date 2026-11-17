import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/socket_client.dart';
import '../../core/models.dart';

/// Нэвтрэлтийн төлөв: null = нэвтрээгүй.
class AuthController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final token = await ref.read(tokenStoreProvider).access;
    if (token == null) return null;
    try {
      final me = await ref.read(dioProvider).get('/me');
      await connectSocket(ref);
      return UserProfile.fromJson(me.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// OTP илгээнэ. Тест орчинд (OTP_PROVIDER=mock) сервер кодыг өөрийг нь
  /// буцаадаг тул апп түүнийг дэлгэцэн дээр харуулж чадна; production-д null.
  Future<String?> requestOtp(String phone, String purpose) async {
    final res = await ref.read(dioProvider).post('/auth/otp/request', data: {
      'phone': phone,
      'purpose': purpose,
    });
    return (res.data as Map<String, dynamic>)['devCode'] as String?;
  }

  /// OTP шалгаад register/reset-д ашиглах ticket буцаана.
  Future<String> verifyOtp(String phone, String purpose, String code) async {
    final res = await ref.read(dioProvider).post('/auth/otp/verify', data: {
      'phone': phone,
      'purpose': purpose,
      'code': code,
    });
    return (res.data as Map<String, dynamic>)['ticket'] as String;
  }

  Future<void> register(String ticket, String name, String password) async {
    final res = await ref.read(dioProvider).post('/auth/register', data: {
      'ticket': ticket,
      'name': name,
      'password': password,
    });
    await _onAuthed(res.data as Map<String, dynamic>);
  }

  Future<void> login(String phone, String password) async {
    final res = await ref.read(dioProvider).post('/auth/login', data: {
      'phone': phone,
      'password': password,
    });
    await _onAuthed(res.data as Map<String, dynamic>);
  }

  Future<void> resetPassword(String ticket, String newPassword) async {
    await ref.read(dioProvider).post('/auth/password/reset', data: {
      'ticket': ticket,
      'newPassword': newPassword,
    });
  }

  Future<void> _onAuthed(Map<String, dynamic> data) async {
    await ref
        .read(tokenStoreProvider)
        .save(data['accessToken'] as String, data['refreshToken'] as String);
    await connectSocket(ref);
    ref.invalidateSelf();
    await future;
  }

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final refresh = await store.refresh;
    if (refresh != null) {
      try {
        await ref
            .read(dioProvider)
            .post('/auth/logout', data: {'refreshToken': refresh});
      } catch (_) {}
    }
    await store.clear();
    state = const AsyncData(null);
  }

  Future<void> refreshProfile() async {
    ref.invalidateSelf();
    await future;
  }
}

final authProvider =
    AsyncNotifierProvider<AuthController, UserProfile?>(AuthController.new);
