import 'dart:convert';

import 'package:avatar_builder/avatar_builder.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:gamatutor_kanban/model/Rekomendasi.dart';
import 'package:gamatutor_kanban/model/avatar_models.dart';
import 'package:gamatutor_kanban/model/user.dart';
import 'package:gamatutor_kanban/pages/card/board.dart';
import 'package:gamatutor_kanban/pages/dashboard/account_screen.dart';
import 'package:gamatutor_kanban/pages/dashboard/config/profile_meta.dart';
import 'package:gamatutor_kanban/pages/dashboard/goals_screen.dart';
import 'package:gamatutor_kanban/pages/dashboard/progress_screen.dart';
import 'package:gamatutor_kanban/pages/dashboard/widgets/user_avatar_profile.dart';
import 'package:gamatutor_kanban/service/SecureTokenStorage.dart';
import 'package:gamatutor_kanban/service/avatarService.dart' as AvatarService;
import 'package:gamatutor_kanban/service/cardService.dart';
import 'package:gamatutor_kanban/model/card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gamatutor_kanban/service/notifService.dart';
import 'package:gamatutor_kanban/service/rekomendasiService.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class Dashboard extends StatefulWidget {
  final User? user;
  const Dashboard({super.key, this.user});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _Achievement {
  final String emoji;
  final String title;
  final bool unlocked;
  _Achievement(this.emoji, this.title, this.unlocked);
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  User? _currentUser;
  Rekomendasi? _quizProfile;
  bool _isLoadingProfile = true;
  bool _isLoading = true;
  final bool _isSpeedDialOpen = false;

  // List data Card utama
  List<Card> _cardsList = [];

  // Helper method untuk mendapatkan sapaan waktu otomatis
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 3 && hour < 11) {
      return 'Selamat Pagi,';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang,';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore,';
    } else {
      return 'Selamat Malam,';
    }
  }

  Map<String, dynamic> _getStrategyInfo(String? key) {
    switch (key?.toLowerCase()) {
      case 'organization':
        return {'name': 'Organization', 'emoji': '🏗️'};
      case 'time_management':
        return {'name': 'Time Management', 'emoji': '⚔️'};
      case 'metacognitive_self_regulation':
        return {'name': 'Metacognitive', 'emoji': '🪞'};
      case 'help_seeking':
        return {'name': 'Help Seeking', 'emoji': '🤝'};
      case 'elaboration':
        return {'name': 'Elaboration', 'emoji': '🧠'};
      case 'rehearsal':
        return {'name': 'Rehearsal', 'emoji': '📚'};
      default:
        return {'name': 'Misterius', 'emoji': '❓'};
    }
  }

  // ─── XP derived dari completed cards ───
  int get _xp => _currentUser?.xp ?? 0;
  int get _xpTarget => (_xp ~/ 500 + 1) * 500;

  // ─── Streak derived (sementara) ───
  // Idealnya dari card_column_movements per hari, tapi jika belum ada
  int get _streakDays {
    if (_cardsList.isEmpty) return 0;
    final dates =
        _cardsList
            .where((c) => c.columnMovements == 'reflection')
            .map((c) => c.reflectionCompletedAt) // ← sesuaikan field
            .whereType<DateTime>()
            .map(
              (d) => DateTime(d.year, d.month, d.day),
            ) // normalize ke date-only
            .toSet() // dedup (multiple card/hari)
            .toList()
          ..sort((a, b) => b.compareTo(a)); // descending: terbaru dulu

    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final daysSinceLast = todayNorm.difference(dates.first).inDays;

    if (daysSinceLast > 1) return 0;

    int streak = 1;
    DateTime prev = dates.first;
    for (int i = 1; i < dates.length; i++) {
      final diff = prev.difference(dates[i]).inDays;
      if (diff == 1) {
        streak++;
        prev = dates[i];
      } else {
        break;
      }
    }
    return streak;
  }

  // ─── Achievement milestones derived ───
  List<_Achievement> get _achievements {
    final total = _cardsList.length;
    final done = _completedTaskCount;
    final focus = _formattedFocusDuration;

    return [
      _Achievement('🎴', 'First Card', total >= 1),
      _Achievement('✅', 'First Done', done >= 1),
      _Achievement('🔥', '5 Done', done >= 5),
      _Achievement('📚', '10 Cards', total >= 10),
      _Achievement('🏆', 'First Hour', focus != '0j'),
    ];
  }

  Avataaar? _currentAvatar;
  bool _isLoadingAvatar = true;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    if (_currentUser == null) {
      _restoreUserFromStorage();
    }
    _loadAllData();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final configJson = await AvatarService.getUserAvatarConfig();
      if (configJson != null) {
        final config = AvatarConfig.fromJson(configJson);
        setState(() {
          _currentAvatar = config.toAvataaar();
        });
      } else {
        setState(() {
          _currentAvatar = Avataaar.random(); // Default jika belum punya
        });
      }
    } catch (e) {
      setState(() => _isLoadingAvatar = false);
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadDashboardData(), _loadQuizProfile()]);
  }

  Future<void> _restoreUserFromStorage() async {
    final userJsonStr = await SecureTokenStorage.getUserJson();
    if (userJsonStr != null) {
      final userData = jsonDecode(userJsonStr);
      setState(() {
        _currentUser = User.fromJson(userData);
      });
    }
  }

  Future<void> _loadQuizProfile() async {
    try {
      final token = await SecureTokenStorage.getToken();

      if (token == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      // Ekstrak userId langsung dari token JWT yang tersimpan
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
      final String userId = decodedToken['userId'] ?? decodedToken['id'];

      final profile = await rekomendasiService.getLatestRecommendation(userId);
      if (mounted) {
        setState(() {
          _quizProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Gagal load quiz profile: $e');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final token = await SecureTokenStorage.getToken();

    if (token != null) {
      try {
        final apiCards = await CardService().getCardsByUser(token);
        if (apiCards.isNotEmpty && mounted) {
          setState(() {
            _cardsList = apiCards;
            _isLoading = false;
          });
          _checkStalledTasks();
          return;
        }
      } catch (e) {
        debugPrint('Koneksi ke database gagal: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _checkStalledTasks() {
    final now = DateTime.now();

    // Hitung tugas yang belum selesai (reflectionCompletedAt null) dan dibuat > 7 hari lalu
    final stalledTasks = _cardsList.where((card) {
      if (card.reflectionCompletedAt != null) return false;
      if (card.createdAt == null) return false;
      return now.difference(card.createdAt!).inDays > 7;
    }).length;

    if (stalledTasks > 0) {
      NotificationService.showInstantNotification(
        id: 2,
        title: 'Tugas Macet Terdeteksi ⚠️',
        body:
            'Kamu punya $stalledTasks tugas yang nganggur lebih dari 7 hari. Yuk, mulai dikit-dikit!',
      );
    }
  }

  int get _completedTaskCount {
    return _cardsList.where((card) {
      final col = (card.computedColumn).toLowerCase();
      return col == 'reflection' || col == 'done' || col == 'completed';
    }).length;
  }

  String get _formattedFocusDuration {
    double totalMinutes = 0;

    for (var card in _cardsList) {
      // Prioritas 1: Hitung selisih langsung dari startTime ke endTime pada kartu utama
      if (card.startTime != null && card.endTime != null) {
        final diff = card.endTime!.difference(card.startTime!);
        if (diff.inMinutes > 0) {
          totalMinutes += diff.inMinutes;
        }
      }
      // Prioritas 2 (Fallback): Jika card utama belum ada endTime, akumulasikan dari subtask yang punya rentang waktu
      else if (card.subtasks.isNotEmpty) {
        for (var sub in card.subtasks) {
          if (sub.startTimeList != null && sub.endTimeList != null) {
            final subDiff = sub.endTimeList!.difference(sub.startTimeList!);
            if (subDiff.inMinutes > 0) {
              totalMinutes += subDiff.inMinutes;
            }
          }
        }
      }
    }

    if (totalMinutes <= 0) return '0j';

    // Jika total menit kurang dari 60, tampilkan dalam bentuk menit (misal: "21 mnt" atau desimal jam)
    if (totalMinutes < 60) {
      return '${totalMinutes.toInt()} mnt';
    }

    final double totalHours = totalMinutes / 60.0;
    if (totalHours % 1 == 0) {
      return '${totalHours.toInt()}j';
    }
    return '${totalHours.toStringAsFixed(1)}j';
  }

  // 3. TUGAS HARI INI: Card yang dijadwalkan pada hari ini
  List<Card> get _todaysTasks {
    final now = DateTime.now();
    final todayOnly = DateTime(now.year, now.month, now.day);

    return _cardsList.where((card) {
      // Ambil tanggal dari deadline atau startTime, abaikan jamnya
      DateTime? targetDate = card.deadline ?? card.startTime;
      if (targetDate == null) return false;

      final targetOnly = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
      );

      // Jika ingin mencocokkan persis hari ini:
      return targetOnly.isAtSameMomentAs(todayOnly);

      // ATAU jika ingin menampilkan SEMUA kartu aktif (agar langsung nampak saat diuji):
      // return true;
    }).toList();
  }

  Widget _buildHomeView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildHeroCard(), // ★ BARU: avatar + XP
          const SizedBox(height: 16),
          _buildDynamicTrainingMission(),
          const SizedBox(height: 16),
          _buildProfileRadarCard(), // ★ BARU: radar chart MSLQ
          const SizedBox(height: 16),
          _buildTodaysTaskList(), // ♻️ Refactor dari _buildTodaysTaskList
          const SizedBox(height: 16),
          _buildAchievementsScroll(), // ★ BARU: horizontal badges
          const SizedBox(height: 20),
        ],
      ),
    );
  }

    Widget _buildDynamicTrainingMission() {
    if (_quizProfile == null || !_quizProfile!.hasQuiz) {
      return Container(
        width: double.infinity, // ✅ Paksa selebar layar
        padding: const EdgeInsets.all(20), // ✅ Samakan padding dengan Hero Card
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), // ✅ Samakan radius dengan Hero Card
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Belum ada profil.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),
      );
    }

    final bool isAllRounder =
        _quizProfile!.userProfile?.toLowerCase().contains('all-rounder') ??
        false;

    final strongestKey = _quizProfile!.dominantStrategy;
    final strongestInfo = _getStrategyInfo(strongestKey);
    final unlocked = _quizProfile!.unlockedFeatures;

    if (unlocked.isEmpty) {
      return Container(
        width: double.infinity, // ✅ Paksa selebar layar
        padding: const EdgeInsets.all(20), // ✅ Samakan padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24), // ✅ Samakan radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(
              isAllRounder
                  ? 'Kamu The All-Rounder! Semua strategimu seimbang dan sangat baik.'
                  : 'Kemampuanmu sudah seimbang!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF047857),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final List<Map<String, dynamic>> weakestInfos = unlocked
        .map((key) => _getStrategyInfo(key))
        .toList();

    return Container(
      width: double.infinity, // ✅ Paksa selebar layar (sama seperti Hero Card)
      padding: const EdgeInsets.all(20), // ✅ Samakan padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // ✅ Samakan radius
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(
                Icons.track_changes_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Misi Latihan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                height: 1.5,
              ),
              children: [
                if (isAllRounder)
                  const TextSpan(
                    text: 'Kamu sudah sangat hebat di semua bidang! 🌟\nNamun, kamu masih bisa memoles beberapa strategi berikut:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  )
                else ...[
                  const TextSpan(text: 'Kamu hebat dalam '),
                  TextSpan(
                    text: '${strongestInfo['name']} ${strongestInfo['emoji']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const TextSpan(
                    text:
                        '.\n\nTapi, strategi berikut masih perlu ditingkatkan:',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: weakestInfos.map((info) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  '${info['name']} ${info['emoji']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB91C1C),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text(
            'Yuk, fokus latih itu bulan ini agar belajarmu lebih seimbang!',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsScroll() {
    final achievements = _achievements;
    final unlockedCount = achievements.where((a) => a.unlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Pencapaian',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unlockedCount/${achievements.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final a = achievements[index];
              return Container(
                width: 84,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: a.unlocked
                      ? const Color(0xFFFFFBEB)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: a.unlocked
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Opacity(
                      opacity: a.unlocked ? 1.0 : 0.3,
                      child: Text(
                        a.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: a.unlocked
                            ? const Color(0xFF92400E)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    final bool hasQuiz =
        (_quizProfile?.userProfile != null &&
        _quizProfile!.userProfile!.isNotEmpty);
    final progress = _xpTarget > 0 ? _xp / _xpTarget : 0.0;
    final bool isAllRounder = _quizProfile?.userProfile?.toLowerCase().contains('all-rounder') ?? false;

    // 3. Pilih Meta yang tepat
    final ProfileMeta meta;
    if (isAllRounder) {
      // ✅ Paksa panggil key 'all_rounder' yang ada di map Anda
      meta = resolveProfileMeta('all_rounder'); 
    } else {
      // Jika bukan all-rounder, pakai logika normal
      meta = resolveProfileMeta(
        (_quizProfile?.unlockedFeatures.isNotEmpty ?? false)
            ? _quizProfile!.unlockedFeatures.last
            : null,
        dominantStrategy: _quizProfile?.dominantStrategy,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // ★ Gradient mengikuti warna profil!
          colors: [
            meta.color,
            meta.color.withValues(alpha: 0.75),
            meta.color.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: meta.color.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // ★ Avatar emoji profil
              _currentAvatar != null
                  ? UserAvatarProfile(
                      avatar: _currentAvatar!,
                      size: 80,
                      isCircle:
                          true, // Widget ini otomatis bikin bentuk lingkaran
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),

              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ★ Nama profil + emoji
                    Row(
                      children: [
                        if (hasQuiz) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  meta.emoji,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  meta.displayName,
                                  style: TextStyle(
                                    color: meta.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(
                                255,
                                6,
                                0,
                                0,
                              ).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Profil belum terpetakan',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Streak pill (tidak berubah)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '$_streakDays',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ★ Tagline profil (1 baris di bawah avatar)
          if (hasQuiz) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meta.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // XP Bar (tidak berubah)
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_xp / $_xpTarget XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroMiniStat('📚', '${_cardsList.length}', 'Cards'),
              _heroMiniStat('✅', '$_completedTaskCount', 'Selesai'),
              _heroMiniStat('⏱️', _formattedFocusDuration, 'Fokus'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMiniStat(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRadarCard() {
    final Map<String, double> rawScores = _quizProfile?.normalizedScores ?? {};
    // Data dummy — nanti dari backend (normalized_scores)
    final scores = {
      'organization': rawScores['organization'] ?? 0.0,
      'time_management': rawScores['time_management'] ?? 0.0,
      // Sesuaikan key 'metacognitive_self_regulation' dengan array categories di bawah
      'metacognitive_self_regulation':
          rawScores['metacognitive_self_regulation'] ?? 0.0,
      'help_seeking': rawScores['help_seeking'] ?? 0.0,
      'elaboration': rawScores['elaboration'] ?? 0.0,
      'rehearsal': rawScores['rehearsal'] ?? 0.0,
    };
    final labels = [
      'Organisasi 🏗️',
      'Waktu ⚔️',
      'Metakognitif 🪞',
      'Bantuan 🤝',
      'Elaborasi 🧠',
      'Latihan 📚',
    ];
    final values = scores.values.toList();
    debugPrint('🔍 Radar Values: $values');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil Kemampuanmu',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Berdasarkan hasil kuis onboarding',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 3;
                  });
                },
                child: const Text(
                  'Detail',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  // 1. Data Asli Anda
                  RadarDataSet(
                    fillColor: const Color(0xFF8B5CF6).withOpacity(0.2),
                    borderColor: const Color(0xFF8B5CF6),
                    borderWidth: 2,
                    entryRadius: 2,
                    dataEntries: values
                        .map((v) => RadarEntry(value: v ?? 0.0))
                        .toList(),
                  ),
                  // 2. ✅ DATA BAYANGAN (Memaksa skala 0-100 agar tidak jadi titik)
                  RadarDataSet(
                    fillColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    entryRadius: 0,
                    dataEntries: const [
                      RadarEntry(value: 100),
                      RadarEntry(value: 100),
                      RadarEntry(value: 100),
                      RadarEntry(value: 100),
                      RadarEntry(value: 100),
                      RadarEntry(value: 100),
                    ],
                  ),
                ],
                radarShape: RadarShape.polygon,
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                ),
                titlePositionPercentageOffset: 0.15,
                getTitle: (index, angle) {
                  const shortLabels = [
                    'Organisasi 🏗️',
                    'Waktu ⚔️',
                    'Metakognitif 🪞',
                    'Bantuan 🤝',
                    'Elaborasi 🧠',
                    'Latihan 📚',
                  ];
                  return RadarChartTitle(text: shortLabels[index], angle: 0);
                },
                titleTextStyle: const TextStyle(
                  fontSize: 8,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                tickCount: 2,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: BorderSide(color: Colors.grey.withOpacity(0.1)),
                gridBorderData: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    switch (_selectedIndex) {
      case 0:
        currentBody = _buildHomeView();
        break;
      case 1:
        currentBody = KanbanBoardView();
        break;
      case 2:
        currentBody = const GoalsScreen();
        break;
      case 3:
        currentBody = ProgressScreen(
          cardsList: _cardsList,
          quizProfile: _quizProfile,
        );
        break;
      case 4:
        currentBody = AccountScreen(
          currentUser: _currentUser,
          quizProfile: _quizProfile,
          userXp: _xp,
          currentAvatar: _currentAvatar,
          onAvatarUpdated: _loadAvatar,
        );
        ;
        break;
      default:
        currentBody = _buildHomeView();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: Stack(children: [currentBody])),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    final displayName = _currentUser?.fullName;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$displayName!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }

  Widget _buildTodaysTaskList() {
    final tasks = _todaysTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📌', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              'Tugas Hari Ini',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const Spacer(),
            if (tasks.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty) _emptyTasksCTA() else _buildTodaysTaskList(),
      ],
    );
  }

  Widget _emptyTasksCTA() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Text('✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          const Text(
            'Belum ada tugas hari ini',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Yuk mulai dengan buat 1 card belajar!',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () => setState(() => _selectedIndex = 1),
            icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Buat Card Pertamamu',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: const Color(0xFF94A3B8),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_kanban_outlined),
            activeIcon: Icon(Icons.view_kanban_rounded),
            label: 'Board',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_outlined),
            activeIcon: Icon(Icons.track_changes_rounded),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart_rounded),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
