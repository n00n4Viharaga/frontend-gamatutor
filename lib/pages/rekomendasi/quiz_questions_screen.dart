import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamatutor_kanban/model/quiz.dart';
import 'package:gamatutor_kanban/pages/rekomendasi/recommendation_dashboard_screen.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';

const _categoryMeta = {
  'organization': (Color(0xFF6366F1), Icons.grid_view_rounded, 'Atur Strategi'),
  'time_management': (
    Color(0xFFEC4899),
    Icons.schedule_rounded,
    'Kelola Waktu',
  ),
  'metacognitive_self_regulation': (
    Color(0xFF8B5CF6),
    Icons.psychology_rounded,
    'Refleksi Diri',
  ),
  'help_seeking': (Color(0xFF06B6D4), Icons.support_rounded, 'Cari Bantuan'),
  'elaboration': (Color(0xFFF59E0B), Icons.link_rounded, 'Hubungkan Ide'),
  'rehearsal': (Color(0xFF10B981), Icons.replay_rounded, 'Latih Ingatan'),
};

class QuizQuestionsScreen extends StatefulWidget {
  const QuizQuestionsScreen({Key? key}) : super(key: key);

  @override
  _QuizQuestionsScreenState createState() => _QuizQuestionsScreenState();
}

class _QuizQuestionsScreenState extends State<QuizQuestionsScreen> {
  late PageController _pageController;
  late ConfettiController _confettiController;

  int currentIndex = 0;
  int xp = 0;
  bool isLoading = true;
  List<MslqQuestion> questions = [];

  final Map<int, int> selectedScores = {};
  final Map<int, int> selectedOptionIndices = {};

  bool _showLoadingOverlay = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    _fetchQuestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String? _fetchError;

  Future<void> _fetchQuestions() async {
    setState(() {
      isLoading = true;
      _fetchError = null;
    });
    try {
      final fetched = await rekomendasiService.getMslqQuestions();
      setState(() {
        questions = fetched;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat soal: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  bool _isAdvancing = false;
  // ─── Interaksi utama: tap opsi → haptic → animasi → auto-advance ───
  Future<void> _handleOptionSelected(int optionIndex, int score) async {
    if (_isAdvancing) return;
    _isAdvancing = true;

    HapticFeedback.mediumImpact();

    final prevScore = selectedScores[currentIndex];
    setState(() {
      selectedOptionIndices[currentIndex] = optionIndex;
      selectedScores[currentIndex] = score;

      if (prevScore != null) xp -= 10 + (prevScore == 3 ? 5 : 0);
      xp += 10 + (score == 3 ? 5 : 0);
    });

    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    if (currentIndex < questions.length - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;

      setState(() {
        currentIndex++;
        _isAdvancing = false; // ⭐ RESET — ini kunci
      });
    } else {
      _finishQuiz();
    }
  }

  bool _submitting = false;

  Future<void> _finishQuiz() async {
    if (_submitting) return;
    _submitting = true;

    HapticFeedback.heavyImpact();
    _confettiController.play();

    // Munculkan layar loading animasi
    setState(() {
      _showLoadingOverlay = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 1500),
    ); // Biarkan confetti jalan dulu
    if (!mounted) return;
    await _submitQuizResult();
  }

  Future<void> _submitQuizResult() async {
    try {
      final payload = <Map<String, dynamic>>[];
      selectedScores.forEach((qIdx, score) {
        if (qIdx < questions.length) {
          payload.add({'category': questions[qIdx].category, 'score': score});
        }
      });

      final hasil = await rekomendasiService.submitQuiz(payload);
      if (!mounted) return;

      setState(() {
        _showLoadingOverlay = false;
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecommendationDashboardScreen(quizResultData: hasil.toJson()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _isAdvancing = false;
        _showLoadingOverlay = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal submit: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _goBack() {
    if (_isAdvancing) return;
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      setState(() => currentIndex--);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _loadingScreen();
    if (questions.isEmpty) return _emptyScreen();

    return PopScope(
      canPop: !_showLoadingOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showLoadingOverlay) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sabar ya, Coach AI sedang menyusun strategimu... 🧠✨',
              ),
              backgroundColor: Color(0xFF8B5CF6),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFC),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _topBar(),
                  _storyProgressBar(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: questions.length,
                      itemBuilder: (context, index) =>
                          _questionPage(index, questions[index]),
                    ),
                  ),
                ],
              ),
            ),
            // Confetti overlay (tampil saat selesai)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                emissionFrequency: 0.05,
                colors: const [
                  Color(0xFF6366F1),
                  Color(0xFFEC4899),
                  Color(0xFF10B981),
                  Color(0xFFF59E0B),
                  Color(0xFF06B6D4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Loading ───
  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFFFAFAFC),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF6366F1))),
    );
  }

  // ─── Empty state ───
  Widget _emptyScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(
                _fetchError ?? 'Tidak ada soal tersedia.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchQuestions,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF0F172A)
          .withOpacity(0.95), // Background gelap transparan
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.2),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ikon Robot AI dengan efek memantul
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Text('🤖', style: TextStyle(fontSize: 60)),
              ),
              const SizedBox(height: 32),
              const Text(
                'Menganalisis Profilmu...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Coach AI sedang meracik strategi\nbelajar terbaik khusus buat kamu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar: back, counter, XP ───
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E293B),
              size: 20,
            ),
            onPressed: _goBack,
          ),
          const Spacer(),
          // XP pill
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFFB923C)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '$xp XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Story-style segmented progress bar ───
  Widget _storyProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(questions.length, (i) {
          final answered = selectedScores.containsKey(i);
          final active = i == currentIndex;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == questions.length - 1 ? 0 : 3),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: answered || active
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Satu halaman pertanyaan ───
  Widget _questionPage(int index, MslqQuestion question) {
    final meta =
        _categoryMeta[question.category] ??
        (const Color(0xFF6366F1), Icons.help_rounded, 'Kuis');
    final color = meta.$1;
    final icon = meta.$2;
    final label = meta.$3;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Category chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Question text (besar & bold, Gen-Z friendly)
          Text(
            question.questionText,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          // Options
          ...question.options.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final isSelected = selectedOptionIndices[index] == idx;
            return _OptionTile(
              key: ValueKey('$index-$idx'),
              text: opt.text,
              isSelected: isSelected,
              accentColor: color,
              onTap: () => _handleOptionSelected(idx, opt.score),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Option tile dengan animasi tap (scale + color)
// ═══════════════════════════════════════════════════════════════
class _OptionTile extends StatefulWidget {
  final String text;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionTile({
    Key? key,
    required this.text,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.accentColor.withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.isSelected
                  ? widget.accentColor
                  : const Color(0xFFE2E8F0),
              width: widget.isSelected ? 2 : 1.2,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.accentColor.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? widget.accentColor
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? widget.accentColor
                        : const Color(0xFFCBD5E1),
                    width: 2,
                  ),
                ),
                child: widget.isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
