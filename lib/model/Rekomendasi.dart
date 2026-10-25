class Rekomendasi {
  final bool hasQuiz;
  final String? userProfile;
  final String? dominantStrategy;
  final List<String> unlockedFeatures;
  final List<String> lockedFeatures;
  
  // ★ TAMBAHKAN INI
  final Map<String, double> normalizedScores; 

  Rekomendasi({
    required this.hasQuiz,
    this.userProfile,
    this.dominantStrategy,
    this.unlockedFeatures = const [],
    this.lockedFeatures = const [],
    this.normalizedScores = const {}, // Default kosong
  });

  factory Rekomendasi.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    final userProfile = json['userProfile'] as String?;

    // ★ EKSTRAK SKOR DARI ANSWERS_PAYLOAD (Ranked)
    final Map<String, double> scores = {};
    final answersPayload = json['answersPayload'];
    if (answersPayload is Map<String, dynamic>) {
      final ranked = answersPayload['ranked'];
      if (ranked is List) {
        for (final item in ranked) {
          if (item is Map && item['category'] != null) {
            scores[item['category'].toString()] = (item['score'] as num?)?.toDouble() ?? 0.0;
          }
        }
      }
    }

    return Rekomendasi(
      hasQuiz: userProfile != null && userProfile.isNotEmpty,
      userProfile: userProfile,
      dominantStrategy: json['dominantStrategy'] as String?,
      unlockedFeatures: parseList(json['unlockedFeatures']),
      lockedFeatures: parseList(json['lockedFeatures']),
      normalizedScores: scores, // ★ Masukkan hasil ekstrak ke sini
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasQuiz': hasQuiz,
      'userProfile': userProfile,
      'dominantStrategy': dominantStrategy,
      'unlockedFeatures': unlockedFeatures,
      'lockedFeatures': lockedFeatures,
      'normalizedScores': normalizedScores,
    };
  }

  String get displayName => userProfile ?? 'Learner';
}