import 'package:flutter_web_plugins/url_strategy.dart';

/// `/#/auctions/..` биш `/auctions/..` хэлбэрийн URL.
/// Hosting талд SPA fallback (бүх зам → index.html) тохируулах шаардлагатай.
void configureUrlStrategy() => usePathUrlStrategy();
