enum ExamDifficulty { easy, medium, hard }

extension ExamDifficultyX on ExamDifficulty {
  String get label {
    switch (this) {
      case ExamDifficulty.easy:
        return 'Easy';
      case ExamDifficulty.medium:
        return 'Medium';
      case ExamDifficulty.hard:
        return 'Hard';
    }
  }

  /// Total study hours to generate for this difficulty level.
  double get totalStudyHours {
    switch (this) {
      case ExamDifficulty.easy:
        return 3.0;
      case ExamDifficulty.medium:
        return 6.0;
      case ExamDifficulty.hard:
        return 10.0;
    }
  }

  /// Number of weekly study task repetitions (used when daysUntilExam > 1 week).
  int get sessionCount {
    switch (this) {
      case ExamDifficulty.easy:
        return 3;
      case ExamDifficulty.medium:
        return 4;
      case ExamDifficulty.hard:
        return 5;
    }
  }
}

