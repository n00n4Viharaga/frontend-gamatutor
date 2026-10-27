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
  bool _needsReflection = false;
  bool _isSubmittingReflection = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMonthlyEvaluation();
  }

  // ═══════════════════════════════════════════════════════════
  // FETCH: GET /check-status
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchMonthlyEvaluation() async {
    setState(() {
      _isLoadingEval = true;
      _errorMessage = null;
    });

    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingEval = false;
          _errorMessage = 'Sesi berakhir. Silakan login lagi.';
        });
        return;
      }

      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api"
          : ApiConstants.getApiBaseUrl('');
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final response = await http
          .get(
            Uri.parse('$cleanBaseUrl/monthly-evaluations/check-status'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final eval = data['show_eval'] == true ? data['evaluation'] : null;
        final issues = eval?['detectedIssues'] ?? {};

        // needs_reflection bisa dari backend ATAU fallback cek stalled
        final needs =
            data['needs_reflection'] == true ||
            ((issues['stalled_cards'] ?? 0) > 0 &&
                issues['user_reflection_reason'] == null);

        setState(() {
          _monthlyEvalData = eval;
          _needsReflection = needs;
          _isLoadingEval = false;
          _errorMessage = null;
        });
      } else {
        debugPrint('❌ check-status ${response.statusCode}: ${response.body}');
        setState(() {
          _isLoadingEval = false;
          _errorMessage = 'Gagal memuat evaluasi (${response.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('Error fetch eval: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingEval = false;
        _errorMessage = 'Tidak dapat terhubung ke server';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SUBMIT REFLEKSI: POST /reflect
  // ═══════════════════════════════════════════════════════════
  Future<void> _submitReflection(String reason) async {
    if (_isSubmittingReflection) return;
    setState(() => _isSubmittingReflection = true);

    try {
      final token = await SecureTokenStorage.getToken();
      if (token == null) return;

      final discovered = await MdnsHelper.discoverService();
      final baseUrl = discovered != null
          ? "http://$discovered:3000/api"
          : ApiConstants.getApiBaseUrl('');
      final cleanBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

      final response = await http
          .post(
            Uri.parse('$cleanBaseUrl/monthly-evaluations/reflect'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'monthYear':
                  DateTime.now().toUtc().toIso8601String().substring(0, 7),
              'userReason': reason,
            }),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📥 reflect ${response.statusCode}: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final eval = data['evaluation'];

        setState(() {
          _monthlyEvalData = eval;
          _needsReflection = false;
          _isSubmittingReflection = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Makasih! Coach AI sudah kasih saran buat kamu 🎯'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      } else {
        setState(() => _isSubmittingReflection = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal kirim refleksi: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error submit reflection: $e');
      if (!mounted) return;
      setState(() => _isSubmittingReflection = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoadingEval) return _buildLoadingScreen();
    if (_errorMessage != null) return _buildErrorScreen();
    if (_monthlyEvalData == null) return _buildEmptyScreen();
    if (_needsReflection) {
      final issues = _monthlyEvalData!['detectedIssues'] ?? {};
      return _buildReflectionPromptScreen(issues);
    }
    return _buildReportScreen();
  }

  // ─── Loading ───────────────────────────────────────────────
  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
      ),
    );
  }

  // ─── Error ─────────────────────────────────────────────────
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😵', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchMonthlyEvaluation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
                child: const Text(
                  'Coba Lagi',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Kosong (belum 30 hari) ────────────────────────────────
  Widget _buildEmptyScreen() {
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
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

  // ─── Refleksi (prompt dulu, skor disembunyikan) ────────────
  Widget _buildReflectionPromptScreen(Map<String, dynamic> issues) {
    final stalled = issues['stalled_cards'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Center(
                child: Column(
                  children: [
                    const Text('🤖', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'Coach AI Mau Nanya Dulu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Jawab jujur ya, biar saran buat kamu lebih tepat 💡',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFFDE68A),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '⚠️ $stalled tugas macet > 7 hari',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Ada kendala apa nih yang bikin kamu susah lanjut?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isSubmittingReflection)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      )
                    else ...[
                      _buildReasonTile('Terlalu susah 😫', 'too_hard'),
                      _buildReasonTile('Bingung mulai 🤔', 'confused'),
                      _buildReasonTile('Sibuk banget ⏱️', 'busy'),
                      _buildReasonTile('Mager / Lupa 😴', 'lazy'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Skor & evaluasi akan muncul setelah kamu jawab ✨',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _submitReflection(value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Report lengkap ────────────────────────────────────────
  Widget _buildReportScreen() {
    final isSync = _monthlyEvalData!['isSynchronized'] ?? false;
    final issues = _monthlyEvalData!['detectedIssues'] ?? {};
    final int score = issues['total_score'] ?? 0;
    final String? userReason = issues['user_reflection_reason'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Monthly Report 📊',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 20),

            // Konteks jawaban user (kalau ada)
            if (userReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Kendala bulan ini: ${_reasonLabel(userReason)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3730A3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Hero Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSync
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isSync
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF43F5E))
                            .withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isSync ? 'Kamu On Track! 🚀' : 'Waduh, Butuh Boost! 🚨',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: score / 100,
                          strokeWidth: 12,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            '$score',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'SKOR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _monthlyEvalData!['llmFeedback'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bento Stats
            const Text(
              'Data Belajar 30 Hari',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildBentoStat(
                  '📚',
                  'Total Tugas',
                  '${issues['total_cards'] ?? 0}',
                  const Color(0xFFEEF2FF),
                  const Color(0xFF4F46E5),
                ),
                const SizedBox(width: 12),
                _buildBentoStat(
                  '✅',
                  'Selesai',
                  '${issues['completion_rate'] ?? 0}%',
                  const Color(0xFFECFDF5),
                  const Color(0xFF10B981),
                ),
                const SizedBox(width: 12),
                _buildBentoStat(
                  '⏱️',
                  'Rata-rata',
                  '${issues['avg_completion_hours'] ?? 0}j',
                  const Color(0xFFFFFBEB),
                  const Color(0xFFF59E0B),
                ),
              ],
            ),

            // CTA
            if (!isSync) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const QuizQuestionsScreen(),
                    ),
                  ),
                  child: const Text(
                    'Ikuti Kuis Ulang & Cari Strategi Baru',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── Helper ────────────────────────────────────────────────
  String _reasonLabel(String code) {
    switch (code) {
      case 'too_hard':
        return 'Terlalu susah 😫';
      case 'confused':
        return 'Bingung mulai 🤔';
      case 'busy':
        return 'Sibuk banget ⏱️';
      case 'lazy':
        return 'Mager / Lupa 😴';
      default:
        return code;
    }
  }

  Widget _buildBentoStat(
    String emoji,
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}