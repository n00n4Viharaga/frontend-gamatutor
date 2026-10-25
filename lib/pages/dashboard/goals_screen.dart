import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/pages/rekomendasi/quiz_questions_screen.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/MdnsHelper.dart';
import 'package:gamatutor_kanban/service/app_config.dart';
import 'package:http/http.dart' as http;

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  Map<String, dynamic>? _monthlyEvalData;
  bool _isLoadingEval = true;

  // State untuk Metacognitive Prompt
  bool _hasAnsweredPrompt = false;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyEvaluation();
  }

  Future<void> _fetchMonthlyEvaluation() async {
    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoadingEval = false);
        return;
      }

      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api"
          : ApiConstants.getApiBaseUrl('');
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

      final response = await http.get(
        Uri.parse('$cleanBaseUrl/monthly-evaluation/check-status'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _monthlyEvalData = data['show_eval'] == true ? data['evaluation'] : null;
            _isLoadingEval = false;
          });
        } else {
          setState(() => _isLoadingEval = false);
        }
      }
    } catch (e) {
      debugPrint('Error fetch eval: $e');
      if (mounted) setState(() => _isLoadingEval = false);
    }
  }

  // Fungsi saat user menjawab pertanyaan reflektif
    Future<void> _submitReflection(String reason) async {
    setState(() => _hasAnsweredPrompt = true);
    
    try {
      final token = await SecureTokenStorage.getToken();
      final baseUrl = ApiConstants.getApiBaseUrl(''); // Sesuaikan
      
      // ★ Kirim jawaban ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/monthly-evaluation/reflect'), // Endpoint baru
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'monthYear': new DateTime.now().toIso8601String().substring(0, 7),
          'userReason': reason, // contoh: 'too_hard', 'lazy', 'busy'
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Makasih atas jujurnya! Coach AI lagi nyiapin saran buat kamu...'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          // Refresh halaman untuk melihat feedback LLM yang baru
          _fetchMonthlyEvaluation(); 
        }
      }
    } catch (e) {
      debugPrint('Error submit reflection: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingEval) return const Scaffold(backgroundColor: Color(0xFFF8FAFC), body: Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6))));
    
    if (_monthlyEvalData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧘‍♂️', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text(
                'Belum Waktunya Evaluasi.\nTeruslah belajar! 🌱',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'Rapor bulananmu akan muncul di sini setelah 30 hari.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    final isSync = _monthlyEvalData!['isSynchronized'] ?? false;
    final issues = _monthlyEvalData!['detectedIssues'] ?? {};
    final int score = issues['total_score'] ?? 0;
    
    // ★ SIMULASI DATA ANOMALI DARI BACKEND
    // Di backend Anda, pastikan mengirim field 'anomalies' (misal: stalled_cards > 0)
    final bool hasStalledCards = (issues['stalled_cards'] ?? 0) > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Report 📊', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 20),

            // ★ 1. METACOGNITIVE PROMPT (Tanya Dulu Jika Ada Anomali)
            if (hasStalledCards && !_hasAnsweredPrompt) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB), // Kuning soft
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🤖 Coach AI Bertanya:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    const SizedBox(height: 8),
                    Text(
                      'Ada ${issues['stalled_cards']} tugas yang macet lebih dari 7 hari. Ada kendala apa nih?',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildReasonChip('Terlalu susah 😫', 'too_hard'),
                        _buildReasonChip('Bingung mulai 🤔', 'confused'),
                        _buildReasonChip('Sibuk banget ⏱️', 'busy'),
                        _buildReasonChip('Mager / Lupa 😴', 'lazy'),
                      ],
                    )
                  ],
                ),
              ),
            ],

            // ★ 2. HERO SCORE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSync ? [const Color(0xFF10B981), const Color(0xFF059669)] : [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: (isSync ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Text(isSync ? 'Kamu On Track! 🚀' : 'Waduh, Butuh Boost! 🚨', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120, height: 120,
                        child: CircularProgressIndicator(
                          value: score / 100, strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        children: [
                          Text('$score', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                          const Text('SKOR', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(_monthlyEvalData!['llmFeedback'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ★ 3. BENTO STATS
            const Text('Data Belajar 30 Hari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBentoStat('📚', 'Total Tugas', '${issues['total_cards'] ?? 0}', const Color(0xFFEEF2FF), const Color(0xFF4F46E5)),
                const SizedBox(width: 12),
                _buildBentoStat('✅', 'Selesai', '${issues['completion_rate'] ?? 0}%', const Color(0xFFECFDF5), const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildBentoStat('⏱️', 'Rata-rata', '${issues['avg_completion_hours'] ?? 0}j', const Color(0xFFFFFBEB), const Color(0xFFF59E0B)),
              ],
            ),

            // ★ 4. CTA BUTTON
            if (!isSync) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QuizQuestionsScreen())),
                  child: const Text('Ikuti Kuis Ulang & Cari Strategi Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChip(String label, String value) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFFDE68A)),
      onPressed: () => _submitReflection(value),
    );
  }

  Widget _buildBentoStat(String emoji, String label, String value, Color bgColor, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}