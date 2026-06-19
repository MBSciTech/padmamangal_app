import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// The deployed Render backend URL.
  static String get baseUrl => 'https://padmamangal-app.onrender.com';

  static String get signupUrl => '$baseUrl/api/auth/signup';
  static String get loginUrl => '$baseUrl/api/auth/login';
}
