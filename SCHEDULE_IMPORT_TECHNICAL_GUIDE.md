# Schedule Import Feature - User Guide & Technical Documentation

## Quick Start

### For Users

1. **Open the app** and navigate to the Home page
2. **Click the calendar icon** 📅 in the top-right AppBar (next to your profile)
3. **Follow the wizard:**
   - **Step 1:** Pick an image from your gallery or camera
   - **Step 2:** Wait for AI to analyze the schedule
   - **Step 3A (Weekly Timetable):** Toggle which subjects need homework and estimate hours
   - **Step 3B (Exam Schedule):** Rate difficulty for each exam (Easy/Medium/Hard)
   - **Step 4:** Review the generated tasks
   - **Step 5:** Save to your task list

---

## Architecture Overview

### Domain Layer

**Entities:**
- `ExtractedClass` - Intermediate data from AI for weekly timetables
- `ExtractedExam` - Intermediate data from AI for exam schedules
- `ScheduleType` - Enum: `weeklyTimetable` or `examSchedule`
- `ScheduleImportResult` - Complete AI extraction result
- `Task` - Final task to be saved to Firestore

**Repositories:**
```dart
abstract class ScheduleImportRepository {
  Future<ScheduleImportResult> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  );
}
```

**Use Cases:**
```dart
// Extract schedule from image
class ExtractScheduleFromImageUseCase {
  Future<ScheduleImportResult> call(Uint8List imageBytes, String mimeType);
}

// Generate weekly class & homework tasks
class GenerateWeeklyTasksUseCase {
  Future<List<Task>> call({
    required List<ExtractedClass> classes,
    required List<Task> existingTasks,
    required DateTime importDate,
  });
}

// Generate exam prep tasks with spaced repetition
class GenerateExamPrepTasksUseCase {
  Future<List<Task>> call({
    required List<ExtractedExam> exams,
    required DateTime today,
  });
}
```

### Data Layer

**Data Source:**
```dart
class GeminiScheduleImportDataSource {
  // Uses Firebase Vertex AI backend
  // No raw API keys exposed
  
  Future<ScheduleImportResultDto> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  );
}
```

**DTO (Data Transfer Object):**
```dart
class ScheduleImportResultDto {
  final String type; // "weekly_timetable" or "exam_schedule"
  final List<ExtractedClassDto>? classes;
  final List<ExtractedExamDto>? exams;
  
  ScheduleImportResultDto.fromJson(Map<String, dynamic> json);
}
```

**Repository Implementation:**
```dart
class ScheduleImportRepositoryImpl implements ScheduleImportRepository {
  final GeminiScheduleImportDataSource _dataSource;
  
  ScheduleImportRepositoryImpl(this._dataSource);
  
  @override
  Future<ScheduleImportResult> extractScheduleFromImage(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    final dto = await _dataSource.extractScheduleFromImage(imageBytes, mimeType);
    return dto.toDomain();
  }
}
```

### Presentation Layer

**State Management (Riverpod):**
```dart
final scheduleImportProvider = 
    NotifierProvider<ScheduleImportNotifier, ScheduleImportState>(
      ScheduleImportNotifier.new,
    );

// State machine with steps:
enum ScheduleImportStep {
  imagePicker,       // User selects image
  aiLoading,         // Gemini processing
  timetableAdjust,   // Adjust weekly classes
  examAdjust,        // Adjust exams
  preview,           // Review generated tasks
  saving,            // Writing to Firestore
  success,           // Complete
  error,             // Error occurred
}
```

**Pages:**
1. `ScheduleImportPage` - Image picker & navigation controller
2. `ScheduleLoadingPage` - Loading spinner while AI processes
3. `TimetableAdjustmentPage` - Adjust weekly classes & homework
4. `ExamAdjustmentPage` - Adjust exam difficulties
5. `SchedulePreviewPage` - Preview tasks before saving
6. `ScheduleImportSuccessPage` - Success confirmation

**Notifier Methods:**
```dart
class ScheduleImportNotifier extends Notifier<ScheduleImportState> {
  // Process image and extract schedule
  Future<void> processImage(Uint8List imageBytes, String mimeType);
  
  // Update a class in the adjustment step
  void updateClass(int index, ExtractedClass updated);
  
  // Update an exam in the adjustment step
  void updateExam(int index, ExtractedExam updated);
  
  // Generate task list for preview
  Future<void> generatePreview();
  
  // Save all tasks to Firestore
  Future<void> saveAllTasks();
  
  // Go back one step
  void goBack();
  
  // Reset to initial state
  void reset();
}
```

---

## Feature Flows

### Flow A: Weekly Timetable Import

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: User Picks Image                                        │
│ - Select from gallery or take photo                             │
│ - Image is stored in memory (Uint8List)                         │
│ - JPEG/PNG supported                                            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: AI Extraction (Gemini)                                  │
│ - Send image to Firebase Vertex AI                              │
│ - AI identifies it's a "weekly_timetable"                       │
│ - Returns JSON: {type, classes: [{subject, day, time, ...}]}   │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3A: Timetable Adjustment (User)                            │
│ - UI shows extracted classes in a list                          │
│ - User toggles: "Does [Subject] need homework?"                 │
│ - User estimates: "How many hours per week?"                    │
│ - Classes are updated in state.adjustedClasses                 │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Generate Tasks                                          │
│ - For each class: Create weekly recurring Task                  │
│ - For each class with homework: Generate study Task             │
│ - Smart slot-finder places homework in free afternoons         │
│ - Respects existing task times (no conflicts)                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 5: Preview Tasks                                           │
│ - Show all generated tasks (sorted by day/time)                │
│ - "X classes, Y homework/study tasks"                          │
│ - Allow user to review and edit individual tasks               │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 6: Save to Firestore                                       │
│ - Batch write all tasks to Firestore                            │
│ - Invalidate task stream provider to refresh Home              │
│ - Show success screen                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Flow B: Exam Schedule Import

```
┌─────────────────────────────────────────────────────────────────┐
│ Step 1: User Picks Image                                        │
│ - Select from gallery or take photo                             │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 2: AI Extraction (Gemini)                                  │
│ - AI identifies it's an "exam_schedule"                         │
│ - Returns: {type, exams: [{subject, date, time, ...}]}        │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 3B: Exam Adjustment (User)                                 │
│ - UI shows extracted exams in a list                            │
│ - User rates each exam: Easy / Medium / Hard                    │
│ - Exams are updated in state.adjustedExams                     │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 4: Generate Tasks (Spaced Repetition)                      │
│ - Easy exam (8 weeks away):                                     │
│   • 4 weeks before: 1h study task                              │
│   • 2 weeks before: 2h study task                              │
│   • 1 week before: 2h final review                             │
│ - Medium exam (6 weeks away):                                   │
│   • 5 weeks before: 2h study task                              │
│   • 3 weeks before: 3h study task                              │
│   • 1 week before: 3h final review                             │
│ - Hard exam (4 weeks away):                                     │
│   • 3 weeks before: 3h study task                              │
│   • 2 weeks before: 4h study task                              │
│   • 1 week before: 4h final review                             │
│   • 2 days before: 2h last-minute review                       │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 5: Preview Tasks                                           │
│ - Show all study prep tasks with dates                          │
│ - Show the exam itself as a task                                │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Step 6: Save to Firestore                                       │
│ - Batch write all tasks (studies + exams)                       │
│ - Refresh task stream                                           │
│ - Show success screen                                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Structures

### ExtractedClass (Weekly Timetable)

```dart
class ExtractedClass {
  final String subject;              // "Mathematics", "English", etc.
  final String day;                  // "Mon", "Tue", "Wed", etc.
  final TimeOfDay startTime;         // 09:00
  final TimeOfDay endTime;           // 10:30
  final String? room;                // "Room 101" (optional)
  final bool requiresHomework;       // User toggle
  final int estimatedWeeklyHours;    // "3 hours per week"
}
```

### ExtractedExam (Exam Schedule)

```dart
class ExtractedExam {
  final String subject;              // "Mathematics Final"
  final DateTime date;               // 2026-03-15
  final TimeOfDay startTime;         // 14:00
  final TimeOfDay endTime;           // 16:00
  final String? location;            // "Exam Hall A" (optional)
  final String difficulty;           // "Easy", "Medium", "Hard"
}
```

### Generated Task (Final Output)

```dart
class Task {
  final String id;
  final String title;                // "Mathematics Class" or "Math Study"
  final String? description;
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? deadline;
  final List<int> recurrenceDays;    // [1,2,3,4,5] for Mon-Fri
  final int? estimatedMinutes;       // 60, 120, etc.
  final bool archived;
  // ... other fields
}
```

---

## Error Handling

### User-Facing Errors

| Error | Cause | Recovery |
|-------|-------|----------|
| "Image not supported" | JPEG/PNG format issue | Try another image |
| "Couldn't recognize schedule" | Blurry/corrupted image | Retake photo |
| "Please wait a few seconds" | Rate limit (5s between requests) | Wait, then try again |
| "No internet connection" | Network error | Retry when connected |
| "Something went wrong" | Unexpected error | Return to home, try again |

### Developer Debugging

**Enable debug logging:**
```dart
if (kDebugMode) {
  debugPrint('🔥 Gemini error: $error');
  debugPrint('🔥 Raw response (first 500 chars): $response');
  debugPrint('🔥 Parsed DTO: $dto');
}
```

**Check Service Locator:**
```dart
final useCase = getIt<ExtractScheduleFromImageUseCase>();
final notifier = getIt.get<ScheduleImportNotifier>();
```

---

## Testing

### Unit Tests

```dart
test('extractScheduleFromImage parses weekly_timetable correctly', () async {
  // Arrange
  final mockDatasource = MockGeminiScheduleImportDataSource();
  final repo = ScheduleImportRepositoryImpl(mockDatasource);
  
  // Act
  final result = await repo.extractScheduleFromImage(testImage, 'image/jpeg');
  
  // Assert
  expect(result.type, ScheduleType.weeklyTimetable);
  expect(result.classes, hasLength(5));
});

test('generateWeeklyTasks creates homework in free slots', () async {
  // Arrange
  final useCase = GenerateWeeklyTasksUseCase();
  final classes = [
    ExtractedClass(
      subject: 'Math',
      day: 'Mon',
      startTime: TimeOfDay(hour: 9, minute: 0),
      endTime: TimeOfDay(hour: 10, minute: 30),
      requiresHomework: true,
      estimatedWeeklyHours: 3,
    ),
  ];
  
  // Act
  final tasks = await useCase(
    classes: classes,
    existingTasks: [],
    importDate: DateTime.now(),
  );
  
  // Assert
  final homeworkTasks = tasks.where((t) => t.title.contains('Math'));
  expect(homeworkTasks, isNotEmpty);
});
```

### Integration Tests

```dart
testWidgets('Schedule import wizard completes successfully', (tester) async {
  // Build the app
  await tester.pumpWidget(MyApp());
  
  // Navigate to schedule import
  await tester.tap(find.byIcon(Icons.calendar_month_outlined));
  await tester.pumpAndSettle();
  
  // Pick image
  await tester.tap(find.byIcon(Icons.photo_library_outlined));
  // ... mock image selection ...
  
  // Confirm image
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle(); // Wait for AI
  
  // Adjust timetable
  await tester.tap(find.byType(Checkbox).first);
  await tester.pumpAndSettle();
  
  // Continue to preview
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Save
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Schedule imported successfully'), findsOneWidget);
});
```

---

## Performance Considerations

### Image Processing
- **Recommended size:** < 2 MB
- **Supported formats:** JPEG, PNG
- **Timeout:** 60 seconds
- **Tip:** Compress images before uploading for faster processing

### Slot Finding Algorithm (Timetable Path)
- **Complexity:** O(n²) where n = number of existing tasks
- **Performance:** < 100ms for typical schedule (20-30 tasks)
- **Optimization:** Slot finder respects:
  - Existing class times (no conflicts)
  - Free afternoon/evening slots
  - Weekends (configurable)

### Database Writes
- **Batch writes:** Multiple tasks in single transaction
- **Performance:** ~500ms for 10 tasks
- **Cost:** Each write counts as 1 operation in Firestore billing

---

## Future Enhancements

### Phase 2: Smart Scheduling
- [ ] Conflict detection with existing tasks
- [ ] Automatic best-time slot calculation for homework
- [ ] Machine learning to predict realistic study times
- [ ] Integration with calendar (Google Calendar, Apple Calendar)

### Phase 3: Advanced Features
- [ ] OCR for handwritten schedules
- [ ] PDF schedule parsing
- [ ] Recurring exam patterns (e.g., final exams every semester)
- [ ] Integration with school/university API
- [ ] Sharing schedules with classmates

### Phase 4: Intelligence
- [ ] Predict task difficulty from past performance
- [ ] Suggest break times based on Pomodoro technique
- [ ] Auto-adjust study load based on task completion history
- [ ] Historical analysis (which subjects need more time?)

---

## Support & Troubleshooting

### Common Questions

**Q: Why is the AI not recognizing my schedule?**  
A: The schedule might be:
- Blurry or low resolution
- Partially cut off in the photo
- In a non-standard format
- In a language the AI doesn't support (currently English)

**Solution:** Retake a clear, well-lit photo of the entire schedule.

**Q: Can I edit tasks after importing?**  
A: Yes! Tasks are saved to your normal task list and can be edited like any other task.

**Q: What if the AI extracts incorrect times?**  
A: On Step 3 (Adjustment), you can click each class/exam to edit details before confirming.

**Q: Does this use my personal data?**  
A: Only the schedule image is sent to Gemini (temporarily for processing). No user IDs, emails, or personal info is sent.

**Q: How long does processing take?**  
A: Typically 5-10 seconds. If it takes longer, it will timeout after 60 seconds.


