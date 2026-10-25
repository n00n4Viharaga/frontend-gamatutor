import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/model/user.dart';
import 'quiz_questions_screen.dart';

class QuizIntroScreen extends StatelessWidget {
  final User? user;

  const QuizIntroScreen({Key? key, this.user, required String userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // Gradient pastel yang lebih cerah & modern
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5F3FF), Color(0xFFFDF2F8)], // Ungu sangat muda ke Pink muda
        ),
        borderRadius: BorderRadius.circular(30), // Sudut lebih membulat
        border: Border.all(color: const Color(0xFFE9D5FF), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Teks jadi ke tengah
        children: [
          // ─── 1. GAMBAR ILUSTRASI (Floating Animation) ───
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              // Efek naik-turun halus (floating)
              return Transform.translate(
                offset: Offset(0, -10 * value), 
                child: child,
              );
            },
            child: Image.asset(
              'lib/assets/quiz_intro_illustration.png',
              height: 140,
              fit: BoxFit.contain,
              // Fallback jika gambar belum ada, agar tidak crash
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.psychology_rounded,
                size: 100,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
          
          const SizedBox(height: 20),

          // ─── 2. BADGE INFO (Playful Chips) ───
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge('⏱️ 3 Menit', const Color(0xFFEC4899)),
              const SizedBox(width: 8),
              _buildBadge('📝 24 Soal', const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 3. JUDUL & DESKRIPSI ───
          const Text(
            'Temukan Vibe Belajarmu! ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E1B4B), // Warna gelap tapi soft
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Jawab kuis seru ini dan dapatkan rekomendasi strategi belajar yang paling cocok buat kamu. Nggak pakai ribet!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF4C1D95),
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 24),

          // ─── 4. TOMBOL CTA (Call to Action) ───
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1), // Indigo cerah
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                shadowColor: const Color(0xFF6366F1).withOpacity(0.5),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact(); // Efek getar saat diklik
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuizQuestionsScreen(),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mulai Kuis Sekarang',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper untuk membuat Badge kecil
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}