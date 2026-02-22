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

