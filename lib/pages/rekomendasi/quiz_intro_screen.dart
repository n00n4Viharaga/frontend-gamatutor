import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/model/user.dart';

import 'quiz_questions_screen.dart'; // Nanti kita buat file ini

class QuizIntroScreen extends StatelessWidget {
  final User? user;
  const QuizIntroScreen({Key? key, this.user, required String userId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFFCE7F3)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧠', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              const Text(
                'Kenali Gaya Belajarmu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF312E81),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ikuti kuis 24 soal (3 menit) untuk dapat rekomendasi strategi belajar yang dipersonalisasi khusus buat kamu.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF4C1D95),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QuizQuestionsScreen(),
                  ),
                );
              },
              child: const Text(
                'Mulai Kuis Sekarang →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
