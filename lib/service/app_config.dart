import 'package:flutter/foundation.dart';
import 'package:gamatutor_kanban/service/MdnsHelper.dart';

class ApiConstants {
  static String? _cachedBaseUrl;
  static String getApiBaseUrl(String path) {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:3000/api$path';
    }
    return 'http://10.73.11.148:3000/api$path'; // device fisik
  }

  static Future<String> getBaseUrl(String path) async {
    if (_cachedBaseUrl != null) {
      return '$_cachedBaseUrl$path';
    }

    final discovered = await MdnsHelper.discoverService();

    if (discovered != null) {
      _cachedBaseUrl = "http://$discovered:3000/api";
    } else {
      _cachedBaseUrl = getApiBaseUrl('');
    }

    return '$_cachedBaseUrl$path';
  }
}
