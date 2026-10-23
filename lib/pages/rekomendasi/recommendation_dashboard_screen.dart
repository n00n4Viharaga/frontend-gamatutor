import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gamatutor_kanban/pages/dashboard/dashboard.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'widgets/llm_coach_card.dart';

// ═══════════════════════════════════════════════════════════════
// Meta kategori (konsisten dengan quiz screen)
// ═══════════════════════════════════════════════════════════════
const _catMeta = {
  'organization':                 (Color(0xFF6366F1), Icons.grid_view_rounded,    'Organisasi'),
  'time_management':              (Color(0xFFEC4899), Icons.schedule_rounded,     'Manajemen Waktu'),
  'metacognitive_self_regulation':(Color(0xFF8B5CF6), Icons.psychology_rounded,   'Metakognitif'),
  'help_seeking':                 (Color(0xFF06B6D4), Icons.support_rounded,      'Cari Bantuan'),
  'elaboration':                  (Color(0xFFF59E0B), Icons.link_rounded,         'Elaborasi'),
  'rehearsal':                    (Color(0xFF10B981), Icons.replay_rounded,       'Latihan'),
};

class RecommendationDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? quizResultData;
  const RecommendationDashboardScreen({Key? key, this.quizResultData})
      : super(key: key);

  @override
  State<RecommendationDashboardScreen> createState() =>
      _RecommendationDashboardScreenState();
}

class _RecommendationDashboardScreenState
    extends State<RecommendationDashboardScreen> {
  String _llmFeedback = '';
  bool _isLoadingFeedback = true;

  @override
  void initState() {
    super.initState();
    _fetchLlmFeedback();
  }

  // ─── Ekstrak skor ternormalisasi dari berbagai bentuk payload ───
  Map<String, double> _extractScores() {
    final data = widget.quizResultData;
    if (data == null) return {};

    // 1) Coba normalized_scores langsung dari backend
    final normalized = data['normalized_scores'] ?? data['normalizedScores'];
    if (normalized is Map) {
      return normalized.map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    }

    // 2) Fallback: hitung dari answers_payload
    final answers = data['answers_payload'] ?? data['answersPayload'];
    if (answers is List) {
      final sums = <String, int>{};
      final counts = <String, int>{};
      for (final a in answers) {
        final cat = a['category'];
        final score = a['score'];
        if (cat is String && score is int) {
          sums[cat] = (sums[cat] ?? 0) + score;
          counts[cat] = (counts[cat] ?? 0) + 1;
        }
      }
      return sums.map((cat, sum) {
        final n = counts[cat] ?? 1;
        final minSum = n;
        final maxSum = n * 3;
        final ratio = maxSum == minSum ? 0 : (sum - minSum) / (maxSum - minSum);
        return MapEntry(cat, (ratio * 100).clamp(0, 100).toDouble());
      });
    }
    return {};
  }

  Future<void> _fetchLlmFeedback() async {
    setState(() => _isLoadingFeedback = true);
    final data = widget.quizResultData;
    final dominant = data?['dominant_strategy'] ?? 'time_management';
    final profile = data?['user_profile'] ?? 'Learner';
    final answers = data?['answers_payload'] ?? {};

    final feedback = await rekomendasiService.generateLlmFeedback(
      dominantStrategy: dominant,
      userProfile: profile,
      answersPayload: answers,
    );

    if (mounted) {
      setState(() {
        _llmFeedback = feedback;
        _isLoadingFeedback = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.quizResultData?['user_profile'] ??
        widget.quizResultData?['userProfile'] ??
        'The Learner';
    final dominant = widget.quizResultData?['dominant_strategy'] ??
        widget.quizResultData?['dominantStrategy'] ??
        'organization';
    final unlocked = List<String>.from(
      widget.quizResultData?['unlocked_features'] ??
          widget.quizResultData?['unlockedFeatures'] ??
          [],
    );
    final scores = _extractScores();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(profile, dominant),
              const SizedBox(height: 20),
              _sectionTitle('Profil Kemampuanmu'),
              const SizedBox(height: 12),
              _radarCard(scores),
              const SizedBox(height: 20),
              if (unlocked.isNotEmpty) ...[
                _sectionTitle('Fokus Latihan Kamu'),
                const SizedBox(height: 12),
                _unlockedScroll(unlocked),
                const SizedBox(height: 20),
              ],
              _sectionTitle('Coach AI'),
              const SizedBox(height: 12),
              LlmCoachCard(
                feedbackText: _llmFeedback,
                isLoading: _isLoadingFeedback,
                onRefresh: _fetchLlmFeedback,
              ),
              const SizedBox(height: 24),
              _ctaButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero card dengan gradient + emoji ───
  Widget _heroCard(String profile, String dominant) {
    final meta = _catMeta[dominant] ??
        (const Color(0xFF6366F1), Icons.emoji_events_rounded, 'Learner');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            meta.$1,
            meta.$1.withOpacity(0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: meta.$1.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(meta.$2, color: Colors.white, size: 28),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('PROFIL KAMU',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tipe Belajar',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            profile,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('🎯', 'Fokus', meta.$3),
              const SizedBox(width: 16),
              _miniStat('⭐', 'XP', '+${24 * 10}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Color(0xFF0F172A),
      ),
    );
  }

  // ─── Radar chart 6 dimensi ───
  Widget _radarCard(Map<String, double> scores) {
    final categories = _catMeta.keys.toList();
    final values = categories.map((c) => scores[c] ?? 0).toList();
    final hasData = values.any((v) => v > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: hasData
          ? SizedBox(
              height: 260,
              child: RadarChart(
                RadarChartData(
                  dataSets: [
                    RadarDataSet(
                      fillColor: const Color(0xFF6366F1).withOpacity(0.2),
                      borderColor: const Color(0xFF6366F1),
                      borderWidth: 2,
                      entryRadius: 4,
                      dataEntries: values
                          .map((v) => RadarEntry(value: v))
                          .toList(),
                    ),
                  ],
                  radarShape: RadarShape.polygon,
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData:
                      BorderSide(color: Colors.grey.withOpacity(0.3)),
                  titlePositionPercentageOffset: 0.18,
                  titleTextStyle: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  getTitle: (index, angle) => RadarChartTitle(
                    text: _catMeta[categories[index]]!.$3,
                  ),
                  tickCount: 4,
                  ticksTextStyle:
                      const TextStyle(color: Colors.transparent),
                  tickBorderData:
                      BorderSide(color: Colors.grey.withOpacity(0.15)),
                  gridBorderData:
                      BorderSide(color: Colors.grey.withOpacity(0.15)),
                ),
              ),
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'Data profil belum tersedia',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            ),
    );
  }

  // ─── Scroll horizontal fitur yang perlu dilatih ───
  Widget _unlockedScroll(List<String> unlocked) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: unlocked.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = unlocked[index];
          final meta = _catMeta[cat] ??
              (const Color(0xFF6366F1), Icons.auto_awesome, cat);
          return Container(
            width: 150,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  meta.$1.withOpacity(0.15),
                  meta.$1.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: meta.$1.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: meta.$1,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(meta.$2, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Text(
                  meta.$3,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: meta.$1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Perlu dilatih',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ctaButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Dashboard()),
          );
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mulai Belajar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}