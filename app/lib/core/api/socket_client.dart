import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
import 'api_client.dart';

/// Апп даяар нэг Socket.IO холболт. JWT-тэй бол хувийн event-үүд
/// (wallet_updated, outbid, auction_won) мөн ирнэ.
final socketProvider = Provider<io.Socket>((ref) {
  final socket = io.io(
    AppConfig.apiBaseUrl,
    io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
  );

  ref.onDispose(socket.dispose);
  return socket;
});

/// Нэвтэрсний дараа token-той дахин холбоно.
Future<void> connectSocket(Ref ref) async {
  final socket = ref.read(socketProvider);
  final token = await ref.read(tokenStoreProvider).access;
  socket.auth = token != null ? {'token': token} : {};
  if (socket.connected) socket.disconnect();
  socket.connect();
}
