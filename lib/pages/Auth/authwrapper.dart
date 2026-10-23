import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/Rekomendasi.dart';
import 'package:gamatutor_kanban/pages/dashboard/dashboard.dart';
import 'package:gamatutor_kanban/pages/login/login.dart';
import 'package:gamatutor_kanban/pages/rekomendasi/quiz_intro_screen.dart';
import 'package:gamatutor_kanban/service/loginService.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'package:gamatutor_kanban/model/user.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = LoginService();
  bool _isChecking = true;
  User? _authenticatedUser;
  Rekomendasi? _quizResult;

  @override
  void initState() {
    super.initState();
    _checkInitialAuthAndQuiz();
  }

  Future<void> _checkInitialAuthAndQuiz() async {
    // 1. Cek apakah user sudah login
    final user = await _authService.tryAutoLogin();
    
    if (user != null) {
      try {
        // 2. Cek ke backend apakah user punya hasil kuis
        final Rekomendasi? rekomen = await rekomendasiService.getLatestRecommendation(user.userId ?? '');
        
        if (mounted) {
          setState(() {
            _authenticatedUser = user;
            _quizResult = rekomen; // Nilai ini akan null jika belum kuis
            _isChecking = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _authenticatedUser = user;
            _quizResult = null; // Jika error/gagal fetch, arahkan ke QuizIntroScreen
            _isChecking = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _authenticatedUser = null;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF2563EB),
          ),
        ),
      );
    }

    // Jika belum login -> Halaman Login
    if (_authenticatedUser == null) {
      return const LoginPage();
    }

    // Jika sudah login tetapi BELUM ADA hasil kuis (data DB kosong) -> QuizIntroScreen
    if (_quizResult == null) {
      return QuizIntroScreen(userId: _authenticatedUser?.userId ?? '');
    }

    // Jika sudah login dan SUDAH PUNYA data kuis di DB -> Dashboard Utama
    return Dashboard(user: _authenticatedUser);
  }
}