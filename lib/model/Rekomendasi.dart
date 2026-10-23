// lib/models/user_quiz_result_model.dart
class Rekomendasi {
  final String quizResultId;
  final String userId;
  final String dominantStrategy;
  final String userProfile;
  final List<String> unlockedFeatures;
  final List<String> lockedFeatures;
  final Map<String, dynamic> answersPayload;

  Rekomendasi({
    required this.quizResultId,
    required this.userId,
    required this.dominantStrategy,
    required this.userProfile,
    required this.unlockedFeatures,
    required this.lockedFeatures,
    required this.answersPayload,
  });

  factory Rekomendasi.fromJson(Map<String, dynamic> json) {
    return Rekomendasi(
      quizResultId: json['quiz_result_id'] ?? json['quizResultId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      dominantStrategy: json['dominant_strategy'] ?? json['dominantStrategy'] ?? '',
      userProfile: json['user_profile'] ?? json['userProfile'] ?? '',
      // Pastikan aman jika null dengan mengembalikan list kosong
      unlockedFeatures: List<String>.from(json['unlocked_features'] ?? json['unlockedFeatures'] ?? []),
      lockedFeatures: List<String>.from(json['locked_features'] ?? json['lockedFeatures'] ?? []),
      answersPayload: json['answers_payload'] ?? json['answersPayload'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quiz_result_id': quizResultId,
      'user_id': userId,
      'dominant_strategy': dominantStrategy,
      'user_profile': userProfile,
      'unlocked_features': unlockedFeatures,
      'locked_features': lockedFeatures,
      'answers_payload': answersPayload,
    };
  }
}