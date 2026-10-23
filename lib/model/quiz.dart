class MslqQuestion {
  final String category;
  final String questionText;
  final List<QuestionOption> options;

  MslqQuestion({required this.category, required this.questionText, required this.options});


  factory MslqQuestion.fromJson(Map<String, dynamic> json) {
    var rawOptions = json['options'] as List? ?? [];
    List<QuestionOption> parsedOptions = rawOptions.map((o) => QuestionOption.fromJson(o)).toList();

    return MslqQuestion(
      category: json['category'] ?? 'time_management',
      questionText: json['question_text'] ?? json['questionText'] ?? 'Pertanyaan tidak tersedia',
      options: parsedOptions
    );
  }
}

class QuestionOption {
  final String text;
  final int score;

  QuestionOption({required this.text, required this.score});

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      text: json['text'] ?? '',
      score: json['score'] ?? 1,
    );
  }
}