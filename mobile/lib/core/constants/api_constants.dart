import 'dart:io';

class ApiConstants {
  // Replace with your Render production URL when deploying
  static const String prodBaseUrl = 'https://medscan-api.onrender.com/api/v1'; // Placeholder or actual
  static const String devBaseUrlIos = 'http://192.168.1.195:8888/api/v1';
  static const String devBaseUrlAndroid = 'http://192.168.1.195:8888/api/v1';

  static String get baseUrl {
    // True production environment check can be done via app flavor/build flags
    const bool isProd = false; // Set to true when building for Render production

    if (isProd) {
      return prodBaseUrl;
    } else {
      return Platform.isAndroid ? devBaseUrlAndroid : devBaseUrlIos;
    }
  }

  static const int defaultTimeout = 45000; // 45s (matching frontend client.ts)
  static const int scanTimeout = 60000;    // 60s
  static const int slowEndpointTimeout = 25000; // 25s
  static const int fastEndpointTimeout = 5000;  // 5s
}
