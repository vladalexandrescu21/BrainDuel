class QuestionModel {
  final String id;
  final String text;
  final List<String> answers; // exactly 4
  final String topic;
  final String difficulty;
  // correctIndex is NOT here — server sends it only in round_result

  const QuestionModel({
    required this.id,
    required this.text,
    required this.answers,
    required this.topic,
    required this.difficulty,
  });

  factory QuestionModel.fromMap(Map<String, dynamic> map) {
    return QuestionModel(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      answers: List<String>.from(map['answers'] as List? ?? []),
      topic: map['topic'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? 'medium',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'answers': answers,
      'topic': topic,
      'difficulty': difficulty,
    };
  }

  // Mock question for testing without a server
  static QuestionModel mock() {
    return const QuestionModel(
      id: 'mock_1',
      text: 'Care este capitala României?',
      answers: ['București', 'Cluj-Napoca', 'Iași', 'Timișoara'],
      topic: 'geography',
      difficulty: 'easy',
    );
  }
}
