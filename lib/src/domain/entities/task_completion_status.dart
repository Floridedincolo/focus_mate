/// Type-safe status for a task on a given date.
///
/// Replaces the old magic-string approach ('completed', 'missed', etc.)
/// and enables exhaustive switch checking.
enum TaskCompletionStatus {
  completed,
  upcoming,
  missed,
  hidden;

  /// Convert from a Firestore string value to enum.
  static TaskCompletionStatus fromString(String value) {
    return switch (value) {
      'completed' => TaskCompletionStatus.completed,
      'missed' => TaskCompletionStatus.missed,
      'hidden' => TaskCompletionStatus.hidden,
      _ => TaskCompletionStatus.upcoming,
    };
  }

  /// Convert to a string for Firestore storage.
  String toValue() => name;
}

