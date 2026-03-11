/// Domain-level exceptions
sealed class DomainException implements Exception {
  final String message;
  final Exception? originalException;

  DomainException(this.message, [this.originalException]);

  @override
  String toString() => message;
}

class TaskRepositoryException extends DomainException {
  TaskRepositoryException(String message, [Exception? originalException])
      : super(message, originalException);
}

class AppManagerException extends DomainException {
  AppManagerException(String message, [Exception? originalException])
      : super(message, originalException);
}

class PlatformException extends DomainException {
  PlatformException(String message, [Exception? originalException])
      : super(message, originalException);
}

class AccessibilityException extends DomainException {
  AccessibilityException(String message, [Exception? originalException])
      : super(message, originalException);
}

// ── Friends ──────────────────────────────────────────────────────────────────

/// Thrown when trying to send a request that already exists (any status).
class FriendshipAlreadyExistsException extends DomainException {
  FriendshipAlreadyExistsException(String message, [Exception? originalException])
      : super(message, originalException);
}

/// Thrown when a [Friendship] document cannot be found in Firestore.
class FriendshipNotFoundException extends DomainException {
  FriendshipNotFoundException(String message, [Exception? originalException])
      : super(message, originalException);
}

/// Thrown when a user tries to accept/decline a request they didn't receive.
class FriendshipPermissionException extends DomainException {
  FriendshipPermissionException(String message, [Exception? originalException])
      : super(message, originalException);
}

// ── Meeting Suggestions ───────────────────────────────────────────────────────

/// Thrown when the AI backend fails to return valid meeting proposals
/// (network error, malformed JSON, quota exceeded, etc.).
class AiSuggestionException extends DomainException {
  AiSuggestionException(String message, [Exception? originalException])
      : super(message, originalException);
}
