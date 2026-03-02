import 'extracted_class.dart';

/// Result returned by the AI extraction use case.
/// Contains only a list of extracted weekly classes.
class ScheduleImportResult {
  final List<ExtractedClass> classes;

  const ScheduleImportResult(this.classes);
}

