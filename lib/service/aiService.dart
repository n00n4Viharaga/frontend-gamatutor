import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secureTokenStorage.dart';
import 'app_config.dart';

class AiService {
  static Future<String> getFirstTimeFeedback(String dominant, String profile) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = await ApiConstants.getBaseUrl('');
      
      final response = await http.post(
        Uri.parse('$baseUrl/llmRekomen/generate-feedback'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'dominantStrategy': dominant, 'userProfile': profile}),
      ).timeout(const Duration(seconds: 5)); // Timeout Flutter

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['feedback'];
      }
      throw Exception('Gagal load feedback');
    } catch (e) {
      return "Gunakan strategi $dominant untuk memecah tugas menjadi sub-tugas kecil!";
    }
  }
}