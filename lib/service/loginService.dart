import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:http/http.dart' as http;
import 'package:gamatutor_kanban/model/user.dart';

import 'app_config.dart';

class LoginService {
  Future<User?> login(String email, String password) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl('');
      final url = Uri.parse('$baseUrl/auth/login');
      debugPrint('Mencoba login ke URL: $url');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        Map<String, dynamic> userData;
        String? token;
        String? refreshToken;

        if (data is Map<String, dynamic> && data.containsKey('user')) {
          userData = Map<String, dynamic>.from(data['user']);
          token = data['token'] ?? data['accessToken'] ?? data['access_token'];
          refreshToken = data['refreshToken'] ?? data['refresh_token'];
        } else {
          userData = Map<String, dynamic>.from(data);
          token =
              userData['token'] ??
              userData['accessToken'] ??
              userData['access_token'];
          refreshToken = userData['refreshToken'] ?? userData['refresh_token'];
        }

        if (token != null) userData['token'] = token;
        if (refreshToken != null) userData['refreshToken'] = refreshToken;

        final user = User.fromJson(userData);

        await SecureTokenStorage.saveSession(
          token: user.token ?? '',
          refreshToken: user.refreshToken ?? '',
          userJson: jsonEncode(user.toJson()),
        );

        return user;
      } else {
        debugPrint('Login gagal dengan status HTTP: ${response.statusCode}');
        return null;
      }
    } on SocketException catch (e) {
      debugPrint('Network SocketException: $e');
      final baseUrl = await ApiConstants.getBaseUrl('/auth');
      throw Exception(
        'Gagal terhubung ke server ($baseUrl). '
        'Pastikan backend berjalan di PC & izin koneksi internet diizinkan.',
      );
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<User?> loginWithGoogle(String idToken) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl('');
      final url = Uri.parse('$baseUrl/auth/login/google');
      debugPrint('Mencoba login ke URL: $url');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        user.token = data['token'];

        await SecureTokenStorage.saveSession(
          token: user.token ?? '',
          refreshToken: user.refreshToken ?? '',
          userJson: jsonEncode(user.toJson()),
        );

        return user;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Login Google error: $e');
      return null;
    }
  }

  Future<User?> tryAutoLogin() async {
    final token = await SecureTokenStorage.getToken();
    final userJsonStr = await SecureTokenStorage.getUserJson();
    if (userJsonStr != null) {
      final userData = jsonDecode(userJsonStr);
      return User.fromJson(userData);
    }
    if (token == null || userJsonStr == null) return null;

    try {
      final userData = jsonDecode(userJsonStr);
      return User.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  Future<User?> refreshAuthToken(String currentToken) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl('');
      final url = Uri.parse('$baseUrl/auth/refresh');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $currentToken',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = User.fromJson(data['user']);
        final newToken = data['token'] as String?;

        if (newToken != null) {
          user.token = newToken;
        }

        await SecureTokenStorage.saveSession(
          token: user.token ?? currentToken,
          refreshToken: user.refreshToken ?? '',
          userJson: jsonEncode(user.toJson()),
        );

        return user;
      } else {
        await SecureTokenStorage.clearSession();
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    await SecureTokenStorage.clearSession();
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl('');
      final url = Uri.parse('$baseUrl/auth/register');

      // Memisah fullName menjadi firstName dan lastName
      final nameParts = fullName.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'firstName': firstName,
              'lastName': lastName,
              'email': email,
              'password': password,
              'username': email.split('@').first,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Register error: $e');
      return false;
    }
  }

  Future<bool> registerWithGoogle({
    required String email,
    required String firstName,
    required String lastName,
    required String username,
  }) async {
    try {
      final baseUrl = await ApiConstants.getBaseUrl('');
      final url = Uri.parse('$baseUrl/auth/register/google');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'firstName': firstName,
              'lastName': lastName,
              'username': username,
            }),
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Register Google error: $e');
      return false;
    }
  }

    static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final baseUrl = ApiConstants.getApiBaseUrl('');
    final response = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return jsonDecode(response.body);
  }

  static Future<String> resetPassword(String token, String newPassword) async {
    final baseUrl = ApiConstants.getApiBaseUrl('');
    final response = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'newPassword': newPassword}),
    );
    final data = jsonDecode(response.body);
    
    if (response.statusCode == 200) return data['message'];
    throw Exception(data['error']);
  }
}
