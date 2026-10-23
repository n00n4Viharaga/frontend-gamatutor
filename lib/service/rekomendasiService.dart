// lib/services/user_quiz_service.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/Rekomendasi.dart';
import 'package:gamatutor_kanban/model/quiz.dart';
import 'package:gamatutor_kanban/service/MdnsHelper.dart';
import 'package:http/http.dart' as http;
import 'package:gamatutor_kanban/service/app_config.dart';
import 'package:gamatutor_kanban/service/secureTokenStorage.dart';
import 'package:gamatutor_kanban/service/app_config.dart';

class rekomendasiService {
  // Mengambil unlocked features berdasarkan userId
  static Future<List<String>> getUnlockedFeatures(
    String userId,
    String token,
  ) async {
    try {
      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api/"
          : ApiConstants.getApiBaseUrl('');
      final response = await http
          .get(
            Uri.parse('$baseUrl/user-quiz-results/latest/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(
              seconds: 5,
            ), // Proteksi agar tidak infinite waiting/gantung
            onTimeout: () => throw Exception('Koneksi timeout ke server.'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final quizResult = data['quizResult'];
        if (quizResult == null) return [];

        // Ambil data unlocked_features dari JSONB (biasanya berupa List<dynamic>)
        final List<dynamic> unlockedJson =
            quizResult['unlocked_features'] ??
            quizResult['unlockedFeatures'] ??
            [];

        return unlockedJson.map((e) => e.toString()).toList();
      }

      // Jika status code bukan 200 (misal 404 belum ada kuis), kembalikan list kosong
      return [];
    } catch (e) {
      print("Error fetching unlocked features: $e");
      return []; // Return kosong agar aman dan langsung mendisable semua chip
    }
  }

  static Future<List<MslqQuestion>> getMslqQuestions() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null) throw Exception('Sesi berakhir, login ulang.');
    final discovered = await MdnsHelper.discoverService();
    final baseUrl = discovered != null
        ? "http://$discovered:3000/api/"
        : ApiConstants.getApiBaseUrl('');
    final response = await http
        .get(
          Uri.parse('$baseUrl/llmRekomen/questions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) throw Exception('Token expired');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      List rawList = data['questions'] ?? [];
      return rawList.map((x) => MslqQuestion.fromJson(x)).toList();
    } else {
      throw Exception('Gagal memuat pertanyaan kuis dari server');
    }
  }

  static Future<Rekomendasi?> getLatestRecommendation(String userId) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api/"
          : ApiConstants.getApiBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/user-quiz-results/latest/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Jika response JSON mengembalikan quizResult null atau kosong
        if (data['quizResult'] == null) {
          return null;
        }
        return Rekomendasi.fromJson(data['quizResult']);
      } else if (response.statusCode == 404) {
        // Jika backend merespons 404 (data kuis tidak ditemukan)
        return null;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching latest recommendation: $e");
      return null; // Fallback ke null agar user diarahkan ke QuizScreen
    }
  }

  static Future<Rekomendasi> submitQuiz(
    List<Map<String, dynamic>> answers,
  ) async {
    final token = await SecureTokenStorage.getToken();
    if (token == null) throw Exception('Sesi berakhir, login ulang.');
    final discovered = await MdnsHelper.discoverService();
    final baseUrl = discovered != null
        ? "http://$discovered:3000/api/"
        : ApiConstants.getApiBaseUrl('');

    final bodyData = jsonEncode({'answersPayload': answers});
    print("DEBUG SUBMIT QUIZ PAYLOAD: $bodyData"); // <-- CEK DI CONSOLE FLUTTER

    final response = await http.post(
      Uri.parse('$baseUrl/user-quiz-results'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: bodyData,
    ).timeout(const Duration(seconds: 30));

    print("DEBUG RESPONSE STATUS: ${response.statusCode}");
    print(
      "DEBUG RESPONSE BODY: ${response.body}",
    ); // <-- CEK ALASAN ERROR 400 DISINI

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final quizResultJson = data['quizResult'] ?? data;
      return Rekomendasi.fromJson(quizResultJson);
    } else {
      throw Exception('Gagal mengirim hasil kuis: ${response.body}');
    }
  }

  static Future<String> generateLlmFeedback({
    required String dominantStrategy,
    required String userProfile,
    required Map<String, dynamic> answersPayload,
  }) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api/"
          : ApiConstants.getApiBaseUrl('');
      final response = await http.post(
        Uri.parse('$baseUrl/llmRekomen/generate-feedback'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'dominantStrategy': dominantStrategy,
          'userProfile': userProfile,
          'answersPayload': answersPayload,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['feedback'] ??
            'Gunakan strategi belajarmu untuk mengorganisir tugas harian di Kanban board.';
      } else {
        return 'Gunakan strategi $dominantStrategy kamu untuk membagi tugas-tugas besar di Kanban board.';
      }
    } catch (e) {
      return 'Gunakan strategi $dominantStrategy kamu untuk membagi tugas-tugas besar di Kanban board.';
    }
  }
}
