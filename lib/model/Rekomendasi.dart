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

    final Map<String, double> scores = {};
    final answersPayload = json['answersPayload'];

    if (answersPayload is Map<String, dynamic>) {
      final rawScores = answersPayload['normalized_scores'];
      if (rawScores is Map) {
        rawScores.forEach((key, value) {
          if (value is num) {
            scores[key.toString()] = value.toDouble();
          }
        });
      }
    }

    return Rekomendasi(
      hasQuiz: userProfile != null && userProfile.isNotEmpty,
      userProfile: userProfile,
      dominantStrategy: json['dominantStrategy'] as String?,
      unlockedFeatures: parseList(json['unlockedFeatures']),
      lockedFeatures: parseList(json['lockedFeatures']),
      normalizedScores: scores
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
