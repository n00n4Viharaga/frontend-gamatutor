import 'dart:convert';

import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/app_config.dart';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> getUserAvatarConfig() async {
  try {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.get(
      Uri.parse('$baseUrl/user-avatar'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['avatar']?['avatarConfig'];
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<void> saveUserAvatarConfig(Map<String, dynamic> config) async {
  final token = await SecureTokenStorage.getToken();
  final baseUrl = await ApiConstants.getBaseUrl('');
  final response = await http.put(
    Uri.parse('$baseUrl/user-avatar'),
    headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    body: jsonEncode({'avatarConfig': config}),
  );
  if (response.statusCode != 200) {
    throw Exception('Gagal menyimpan avatar');
  }
}