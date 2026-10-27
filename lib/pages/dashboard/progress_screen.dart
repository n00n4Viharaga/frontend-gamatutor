import 'package:flutter/material.dart' hide Card;
import 'package:gamatutor_kanban/model/card.dart';
import 'package:gamatutor_kanban/model/Rekomendasi.dart';
import 'package:fl_chart/fl_chart.dart';

class ProgressScreen extends StatefulWidget {
  final List<Card> cardsList;
  final Rekomendasi? quizProfile;

  const ProgressScreen({Key? key, required this.cardsList, this.quizProfile})
    : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    List<Card> cards = widget.cardsList;

    // ─── 1. DATA DASAR ───
    int totalCards = cards.length;
    int completedCards = cards
        .where((c) => c.computedColumn.toLowerCase() == 'reflection')
        .length;
    double completionRate = totalCards > 0
        ? (completedCards / totalCards) * 100
        : 0;

    int planningCount = cards
        .where((c) => c.computedColumn.toLowerCase() == 'planning')
        .length;
    int monitoringCount = cards
        .where((c) => c.computedColumn.toLowerCase() == 'monitoring')
        .length;
    int controllingCount = cards
        .where((c) => c.computedColumn.toLowerCase() == 'controlling')
        .length;
    int reflectionCount = cards
        .where((c) => c.computedColumn.toLowerCase() == 'reflection')
        .length;

    // ─── 2. DETEKSI TUGAS MACET (> 7 Hari) ───
    final stalledCards = cards.where((c) {
      final col = c.computedColumn.toLowerCase();
      if (col == 'reflection') return false;
      if (c.createdAt == null) return false;
      final diff = DateTime.now().difference(c.createdAt!).inDays;
      return diff > 7;
    }).toList();

    // ─── 3. DATA MSLQ ───
    final scores = widget.quizProfile?.normalizedScores ?? {};
    final categories = [
      'organization',
      'time_management',
      'metacognitive_self_regulation',
      'help_seeking',
      'elaboration',
      'rehearsal',
    ];
    final values = categories.map((c) {
      final val = scores[c];
      return val is num ? val?.toDouble() : 0.0;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        // ✅ 1. BUNGKUS DENGAN LAYOUTBUILDER UNTUK RESPONSIVE
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Jika lebar > 600 (Tablet), maka isTablet = true
            final bool isTablet = constraints.maxWidth > 600;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Stats ✨',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 20),

                // ★ PERINGATAN TUGAS MACET (Jika Ada)
                if (stalledCards.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${stalledCards.length} Tugas Macet',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tugas ini udah nganggur > 7 hari. Yuk, mulai dikit-dikit!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ★ HERO CARD (Completion Rate)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completion Rate',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${completionRate.toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$completedCards dari $totalCards Tugas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ✅ 2. LOGIKA RESPONSIVE UNTUK WEEKLY RECAP & MISI
                if (isTablet) ...[
                  // --- TAMPILAN TABLET: Berdampingan (Kiri & Kanan) ---
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildWeeklyRecap(cards)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDynamicTrainingMission()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // --- TAMPILAN HP: Weekly Recap Full Width di bawah Completion Rate ---
                  _buildWeeklyRecap(cards),
                  const SizedBox(height: 24),
                ],

                // ★ BENTO GRID: FOKUS & PROFIL KEMAMPUAN (Tetap Berdampingan)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // KIRI: FOKUS (Donut)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(
                                  255,
                                  248,
                                  248,
                                  248,
                                ).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Fokus Kamu 🎯',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 120,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 3,
                                        centerSpaceRadius: 35,
                                        sections: [
                                          PieChartSectionData(
                                            color: const Color(0xFF10B981),
                                            value: reflectionCount.toDouble(),
                                            radius: 15,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            color: const Color(0xFF3B82F6),
                                            value: controllingCount.toDouble(),
                                            radius: 15,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            color: const Color(0xFFF59E0B),
                                            value: monitoringCount.toDouble(),
                                            radius: 15,
                                            showTitle: false,
                                          ),
                                          PieChartSectionData(
                                            color: const Color(0xFFEF4444),
                                            value: planningCount.toDouble(),
                                            radius: 15,
                                            showTitle: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  _buildLegend(
                                    'Selesai',
                                    const Color(0xFF10B981),
                                    reflectionCount,
                                  ),
                                  _buildLegend(
                                    'Cek',
                                    const Color(0xFF3B82F6),
                                    controllingCount,
                                  ),
                                  _buildLegend(
                                    'Proses',
                                    const Color(0xFFF59E0B),
                                    monitoringCount,
                                  ),
                                  _buildLegend(
                                    'Rencana',
                                    const Color(0xFFEF4444),
                                    planningCount,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // KANAN: PROFIL (Radar)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromARGB(
                                  255,
                                  248,
                                  248,
                                  248,
                                ).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profil Kemampuan 🧠',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 220,
                                    child: RadarChart(
                                      RadarChartData(
                                        dataSets: [
                                          // 1. Data Asli Anda
                                          RadarDataSet(
                                            fillColor: const Color(0xFF8B5CF6)
                                                .withOpacity(0.2),
                                            borderColor: const Color(
                                              0xFF8B5CF6,
                                            ),
                                            borderWidth: 2,
                                            entryRadius: 2,
                                            dataEntries: values
                                                .map(
                                                  (v) => RadarEntry(
                                                    value: v ?? 0.0,
                                                  ),
                                                )
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
                                        radarBackgroundColor:
                                            Colors.transparent,
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
                                          return RadarChartTitle(
                                            text: shortLabels[index],
                                            angle: 0,
                                          );
                                        },
                                        titleTextStyle: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        tickCount: 2,
                                        ticksTextStyle: const TextStyle(
                                          color: Colors.transparent,
                                        ),
                                        tickBorderData: BorderSide(
                                          color: Colors.grey.withOpacity(0.1),
                                        ),
                                        gridBorderData: BorderSide(
                                          color: Colors.grey.withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ 3. FOOTER (Misi Latihan di bawah khusus HP)
                if (!isTablet) ...[
                  const SizedBox(height: 24),
                  _buildDynamicTrainingMission(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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

  Widget _buildDynamicTrainingMission() {
  if (widget.quizProfile == null || !widget.quizProfile!.hasQuiz) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: const Center(child: Text('Belum ada profil.', style: TextStyle(fontSize: 14, color: Colors.grey))),
    );
  }

  // ✅ Cek apakah dia The All-Rounder
  final bool isAllRounder = widget.quizProfile!.userProfile?.toLowerCase().contains('all-rounder') ?? false;
  
  final strongestKey = widget.quizProfile!.dominantStrategy;
  final strongestInfo = _getStrategyInfo(strongestKey);
  final unlocked = widget.quizProfile!.unlockedFeatures;

  // Jika semua kemampuan sudah seimbang (tidak ada yang di-unlock)
  if (unlocked.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
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
            style: const TextStyle(fontSize: 14, color: Color(0xFF047857), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ... (Sisa kode untuk menampilkan Chips misi latihan tetap sama seperti sebelumnya)
  final List<Map<String, dynamic>> weakestInfos = unlocked.map((key) => _getStrategyInfo(key)).toList();

  return Container(
    // ... (Kode Container Misi Latihan Anda)
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: const [
            Icon(Icons.track_changes_rounded, color: Color(0xFF8B5CF6), size: 20),
            SizedBox(width: 8),
            Text('Misi Latihan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
            children: [
              // ✅ Ubah teks jika dia All-Rounder
              if (isAllRounder)
                const TextSpan(
                  text: 'Kamu sudah sangat hebat di semua bidang! 🌟\nNamun, kamu masih bisa memoles beberapa strategi berikut:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                )
              else ...[
                const TextSpan(text: 'Kamu hebat dalam '),
                TextSpan(
                  text: '${strongestInfo['name']} ${strongestInfo['emoji']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
                const TextSpan(text: '.\n\nTapi, strategi berikut masih perlu ditingkatkan:'),
              ]
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Chips Misi
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: weakestInfos.map((info) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                '${info['name']} ${info['emoji']}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Yuk, fokus latih itu bulan ini agar belajarmu lebih seimbang!',
          style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontStyle: FontStyle.italic),
        ),
      ],
    ),
  );
}

  Widget _buildWeeklyRecap(List<Card> cards) {
    final now = DateTime.now();

    // Tentukan awal minggu ini (Senin) dan awal minggu lalu
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

    int completedThisWeek = 0;
    int completedLastWeek = 0;
    double focusHoursThisWeek = 0;

    for (var card in cards) {
      // ★ 1. Ambil data sebagai String
      final String? compDateStr = card.reflectionCompletedAt;

      if (compDateStr != null && compDateStr.isNotEmpty) {
        // ★ 2. Ubah String menjadi DateTime (gunakan tryParse agar tidak crash jika format salah)
        final DateTime? compDate = DateTime.tryParse(compDateStr);

        if (compDate != null) {
          // Cek apakah selesai minggu ini
          if (compDate.isAfter(startOfWeek) ||
              compDate.isAtSameMomentAs(startOfWeek)) {
            completedThisWeek++;

            // Hitung total jam fokus minggu ini
            final String? startTimeStr = card.startTime.toString();
            if (startTimeStr != null && startTimeStr.isNotEmpty) {
              final DateTime? startTime = DateTime.tryParse(startTimeStr);
              if (startTime != null) {
                focusHoursThisWeek +=
                    compDate.difference(startTime).inMinutes / 60.0;
              }
            }
          }
          // Cek apakah selesai minggu lalu
          else if (compDate.isAfter(startOfLastWeek) ||
              compDate.isAtSameMomentAs(startOfLastWeek)) {
            completedLastWeek++;
          }
        }
      }
    }

    // Hitung tren (naik/turun) dengan nada yang empatik
    int trend = completedThisWeek - completedLastWeek;
    String trendText;
    Color trendBgColor;

    if (trend > 0) {
      trendText = 'Mantap! Naik $trend tugas dari minggu lalu. Pertahankan! 🔥';
      trendBgColor = const Color.fromARGB(
        255,
        68,
        120,
        223,
      ).withOpacity(0.2); // Hijau
    } else if (trend < 0) {
      trendText = 'Sepertinya minggu ini berat ya? Nggak apa-apa, istirahat sejenak itu penting. 💙';
      trendBgColor = const Color(0xFFF59E0B).withOpacity(0.2); // Oranye
    } else {
      trendText =
          'Progres stabil. Yuk, coba selesaikan 1 tugas lagi minggu depan! ✨';
      trendBgColor = const Color.fromARGB(255, 176, 105, 217).withOpacity(0.15);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 248, 248, 248).withOpacity(0.3),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('📅', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: const Text(
                        'Weekly Recap',
                        style: TextStyle(
                          color: Color.fromARGB(255, 0, 0, 0),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(
                    0.1,
                  ), // (Opsional) Ubah warna agar kontras
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Minggu Ini',
                  style: TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completedThisWeek',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'Tugas Selesai',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${focusHoursThisWeek.toStringAsFixed(1)}j',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const Text(
                      'Jam Fokus',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: trendBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              trendText,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
