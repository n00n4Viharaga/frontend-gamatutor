import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/learningStrat.dart';
import 'package:http/http.dart' as http;
import 'package:gamatutor_kanban/model/card.dart' as model;
import 'package:gamatutor_kanban/model/cardlist.dart';
import 'package:gamatutor_kanban/model/columnmovement.dart';
import 'package:gamatutor_kanban/service/app_config.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';

class CardService {
  //Mengambil LearningId
  static Future<String?> fetchLearningIdByName(String strategyName) async {
    try {
      final token =
          await SecureTokenStorage.getToken(); // Jika endpoint butuh token auth

      final formattedName = strategyName.toLowerCase();
      final baseUrl = await ApiConstants.getBaseUrl('');

      // Menggunakan baseUrl dari ApiConstants
      final response = await http.get(
        Uri.parse('$baseUrl/learning-strats/$formattedName'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("RAW JSON DARI BACKEND: $data");
        return data['learningStrat']?['learningId'];
      }
      return null;
    } catch (e) {
      print("Error fetching learning strategy ID: $e");
      return null;
    }
  }

  //Mengambil Semua LearningStrategy
  static Future<List<dynamic>> getAllStrategies() async {
    try {
      final token =
          await SecureTokenStorage.getToken(); // Jika endpoint butuh token auth
      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/learning-strats'), // Pastikan URL endpoint ini benar (misal: http://10.0.2.2:3000/api/learning-strats)
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);

        // Cek apakah balasan berupa Map dengan key 'learningStrats' atau langsung List
        if (decodedBody is Map && decodedBody.containsKey('learningStrats')) {
          final List<dynamic> data = decodedBody['learningStrats'];
          return data;
        } else if (decodedBody is List) {
          return decodedBody; // Jaga-jaga kalau format backend berubah jadi List langsung
        }
      }
      return [];
    } catch (e) {
      debugPrint('ERROR SAAT FETCH STRATEGIES: $e');
      return [];
    }
  }

  static Future<LearningStrat?> getStrategyById(
    String token,
    String learningId,
  ) async {
    try {
      final token = await SecureTokenStorage.getToken();

      print("🔑 [FLUTTER] Token yang dikirim: $token");

      if (token == null) {
        print("❌ [FLUTTER] Token NULL! User harus login ulang.");
      }

      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/learning-strats/$learningId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        // Ambil data dengan aman dari berbagai kemungkinan key pembungkus backend
        final targetJson =
            decodedData['learningStrat'] ??
            decodedData['learning_strat'] ??
            decodedData['data'] ??
            decodedData;

        if (targetJson != null) {
          return LearningStrat.fromJson(targetJson);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching strategy by ID: $e");
      return null;
    }
  }

  Future<List<model.Card>> getCardsByUser(String token) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/cards'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // TAMBAHKAN DEBUG PRINT INI UNTUK MELIHAT ISI JSON DARI BACKEND
        debugPrint('RAW JSON CARDS RESPONSE: $jsonResponse');

        final List<dynamic> body = jsonResponse['cards'] ?? [];

        List<model.Card> cards = body
            .map((dynamic item) => model.Card.fromJson(item))
            .toList();

        return cards;
      } else {
        debugPrint('Gagal mengambil cards: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('CardService Error: $e');
      return [];
    }
  }

  // Mengambil CardList berdasarkan cardId
  Future<CardList?> getCardList(String token, String cardId) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/cards/$cardId/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return CardList.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Mengambil Column Movements berdasarkan cardId
  Future<List<ColumnMovement>> getColumnMovements(
    String token,
    String cardId,
  ) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.get(
        Uri.parse('$baseUrl/column-movements/card/$cardId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        return body.map((item) => ColumnMovement.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Membuat Card Utama (Masuk ke tabel cards)
  Future<Map<String, dynamic>> createCard(
    String token,
    Map<String, dynamic> cardData,
  ) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.post(
      Uri.parse('$baseUrl/cards'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(cardData),
    );

    print("STATUS: ${response.statusCode}");
    print("PESAN ERROR BACKEND: ${response.body}");

    if (response.statusCode == 201 || response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['data'] ?? jsonResponse['card'] ?? jsonResponse;
    } else {
      throw Exception('Gagal membuat card: ${response.body}');
    }
  }

  // Membuat Subtask (Masuk ke tabel card_list)
  Future<void> createCardList(
    String token,
    String cardId,
    Map<String, dynamic> subTaskData,
  ) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.post(
      Uri.parse('$baseUrl/cards/$cardId/list'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(subTaskData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal membuat card list: ${response.body}');
    }
  }

  // Memperbarui Card Utama (PUT /api/cards/:cardId)
  Future<bool> updateCard(
    String token,
    String cardId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = await ApiConstants.getBaseUrl('');
      final response = await http.put(
        Uri.parse('$baseUrl/cards/$cardId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updateData), // Pastikan di-encode ke JSON string
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating card: $e');
      return false;
    }
  }

  Future<void> updateCardList(
    String token,
    String cardId,
    String clId,
    Map<String, dynamic> subTaskData,
  ) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.put(
      Uri.parse('$baseUrl/cards/$cardId/list/$clId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(subTaskData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal update card list: ${response.body}');
    }
  }

  Future<bool> deleteCard(String token, String cardId) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.delete(
      Uri.parse('$baseUrl/cards/$cardId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    debugPrint(
      '🗑️ DELETE status=${response.statusCode} body=${response.body}',
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  // Menghapus Subtask (DELETE /api/cards/:cardId/list)
  Future<void> deleteCardList(String token, String cardId, String clId) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.delete(
      Uri.parse('$baseUrl/cards/$cardId/list/$clId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Gagal menghapus card list: ${response.body}');
    }
  }

  // Menambahkan Teman Kolaborasi (Masuk ke tabel card_list_collab)
  Future<void> addCollaborator(
    String token,
    String cardId,
    Map<String, dynamic> collabData,
  ) async {
    final token = await SecureTokenStorage.getToken();
    final baseUrl = await ApiConstants.getBaseUrl('');
    final response = await http.post(
      Uri.parse(
        '$baseUrl/card-list-collab/card/$cardId',
      ), // Sesuaikan endpoint backend Anda
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(collabData),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Gagal menambahkan kolaborator: ${response.body}');
    }
  }
}
