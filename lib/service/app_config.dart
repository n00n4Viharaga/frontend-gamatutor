import 'package:flutter/foundation.dart';

class ApiConstants {
  static String  getApiBaseUrl(String path){
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      return 'http://localhost:3000/api$path';
    }
    return 'http://192.168.1.66:3000/api$path'; // device fisik
  }
}
