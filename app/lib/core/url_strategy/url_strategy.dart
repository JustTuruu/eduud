/// Платформоос хамаарч web дээр path URL strategy асаана, бусад дээр юу ч хийхгүй.
library;
export 'url_strategy_io.dart' if (dart.library.js_interop) 'url_strategy_web.dart';
