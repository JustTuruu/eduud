import 'package:web/web.dart' as web;

const _prefix = 'eduud.';

Future<String?> storageRead(String key) async => web.window.localStorage.getItem('$_prefix$key');
Future<void> storageWrite(String key, String value) async =>
    web.window.localStorage.setItem('$_prefix$key', value);
Future<void> storageDelete(String key) async => web.window.localStorage.removeItem('$_prefix$key');
