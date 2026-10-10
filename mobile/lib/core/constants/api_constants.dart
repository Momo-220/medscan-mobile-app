import 'dart:io';

class ApiConstants {
  // Replace with your Render production URL when deploying
  static const String prodBaseUrl = 'https://medscan-app-xx6a.onrender.com/api/v1';
  static const String devBaseUrlIos = 'http://192.168.1.195:8888/api/v1';
  static const String devBaseUrlAndroid = 'http://192.168.1.195:8888/api/v1';

  static String get baseUrl {
    // True production environment check can be done via app flavor/build flags
    const bool isProd = true; // Set to true when building for Render production

    if (isProd) {
      return prodBaseUrl;
    } else {
      return Platform.isAndroid ? devBaseUrlAndroid : devBaseUrlIos;
    }
  }

  static String get serverBaseUrl {
    return baseUrl.replaceAll('/api/v1', '');
  }

  /// Resolves any image URL, storage key (scans/...), or relative path to a valid absolute network URL
  static String resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final url = rawUrl.trim();

    // Already an absolute HTTP URL
    if (url.startsWith('http://') || url.startsWith('https://')) {
      if (url.contains('localhost:8888') || url.contains('127.0.0.1:8888')) {
        return url.replaceAll(RegExp(r'https?://(localhost|127\.0\.0\.1):8888'), serverBaseUrl);
      }
      return url;
    }

    // Relative endpoint (e.g. /api/v1/images/...)
    if (url.startsWith('/api/v1/images/')) {
      return '$serverBaseUrl$url';
    }
    if (url.startsWith('/')) {
      return '$serverBaseUrl/api/v1/images$url';
    }

    // R2 storage key (scans/...) or MongoDB ObjectId (24 chars) or filename
    return '$serverBaseUrl/api/v1/images/$url';
  }

  static const int defaultTimeout = 45000; // 45s (matching frontend client.ts)
  static const int scanTimeout = 60000;    // 60s
  static const int slowEndpointTimeout = 25000; // 25s
  static const int fastEndpointTimeout = 5000;  // 5s
}
