import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const int port = 3000;

  /// Resolves the backend base URL for the current platform.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:$port';
    }
    if (Platform.isAndroid) {
      // Android emulator maps host machine localhost to 10.0.2.2
      return 'http://10.0.2.2:$port';
    }
    return 'http://localhost:$port';
  }

  static String get signupUrl => '$baseUrl/api/auth/signup';
  static String get loginUrl => '$baseUrl/api/auth/login';
}
