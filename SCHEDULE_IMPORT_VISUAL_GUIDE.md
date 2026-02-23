# Schedule Import - Visual Implementation Guide

## Before vs After

### BEFORE: Feature Was Inaccessible ❌

```
┌─────────────────────────────────────┐
│          FOCUS MATE APP             │
├─────────────────────────────────────┤
│  Home      Focus    Stats   Profile  │
│  ┌─────────────────────────────────┐ │
│  │ Monday, 23rd of February 2026   │ │
│  │ Your plan for Today             │ │
│  │                                 │ │
│  │    [Profile Avatar Button]  ◄─ Only button │
│  │                                 │ │
│  │ Calendar: M T W T F S S         │ │
│  │ ┌──┬──┬──┬──┬──┬──┬──┐         │ │
│  │ │21│22│23│24│25│26│27│         │ │
│  │ └──┴──┴──┴──┴──┴──┴──┘         │ │
│  │                                 │ │
│  │ [Task List]                     │ │
│  │ • Mathematics Class - 09:00     │ │
│  │ • English Class - 10:30         │ │
│  │ • Lunch - 12:00                 │ │
│  │                                 │ │
│  └─────────────────────────────────┘ │
│  [FAB: + Button]                     │
└─────────────────────────────────────┘

❌ PROBLEM: No way to access Schedule Import!
   Users can't trigger the feature.
```

### AFTER: Feature Is Easily Accessible ✅

```
┌─────────────────────────────────────┐
│          FOCUS MATE APP             │
├─────────────────────────────────────┤
│  Home      Focus    Stats   Profile  │
│  ┌─────────────────────────────────┐ │
│  │ Monday, 23rd of February 2026   │ │
│  │ Your plan for Today             │ │
│  │                                 │ │
│  │ [📅] [Profile Avatar Button]    │ │
│  │  ▲                               │ │
│  │  └─ NEW: Schedule Import Button  │ │
│  │     (Calendar Icon)              │ │
│  │                                 │ │
│  │ Calendar: M T W T F S S         │ │
│  │ ┌──┬──┬──┬──┬──┬──┬──┐         │ │
│  │ │21│22│23│24│25│26│27│         │ │
│  │ └──┴──┴──┴──┴──┴──┴──┘         │ │
│  │                                 │ │
│  │ [Task List]                     │ │
│  │ • Mathematics Class - 09:00     │ │
│  │ • English Class - 10:30         │ │
│  │ • Lunch - 12:00                 │ │
│  │                                 │ │
│  └─────────────────────────────────┘ │
│  [FAB: + Button]                     │
└─────────────────────────────────────┘

✅ SOLUTION: Calendar button in AppBar
   Users can easily access the feature!
```

---

## User Journey Flow

### Accessing the Feature

```
User on Home Page
        │
        ▼
    Sees 📅 icon in top-right
        │
        ▼
    Taps calendar icon
        │
        ▼
┌─────────────────────────────────────┐
│       SCHEDULE IMPORT WIZARD        │
│                                     │
│  Step 1: Pick an Image              │
│  ┌───────────────────────────────┐  │
│  │    📷 [Camera] [Gallery]      │  │
│  │                               │  │
│  │   [Preview Area]              │  │
│  │   ┌───────────────────────┐   │  │
│  │   │  (Your schedule photo)│   │  │
│  │   └───────────────────────┘   │  │
│  │                               │  │
│  │   [Cancel]     [Continue ►]   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │
        ▼ Tap Continue
┌─────────────────────────────────────┐
│  Step 2: AI is Processing...        │
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │    ⏳ Analyzing your         │  │
│  │       schedule...             │  │
│  │                               │  │
│  │    [████████░░░░░░ 75%]      │  │
│  │                               │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │
        ▼ AI Done
        │
   ┌─────────────┐
   │ Type Check  │
   └─────────────┘
        │
   ┌────┴────┐
   │          │
   ▼ Timetable ▼ Exam
   ▼          ▼
┌──────────┐ ┌──────────┐
│Step 3A:  │ │Step 3B:  │
│Timetable │ │Exams     │
└──────────┘ └──────────┘
   │          │
   ▼          ▼
┌─────────────────────────────────────┐
│  Step 4: Review & Generate          │
│  ┌───────────────────────────────┐  │
│  │ [✓] Task 1 - Math Class       │  │
│  │ [✓] Task 2 - Math Homework    │  │
│  │ [✓] Task 3 - English Class    │  │
│  │ [✓] Task 4 - English Study    │  │
│  │                               │  │
│  │ Total: 4 tasks                │  │
│  │                               │  │
│  │   [Back]     [Save Tasks ►]   │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │
        ▼ Save
┌─────────────────────────────────────┐
│  Step 5: Success! ✅                │
│  ┌───────────────────────────────┐  │
│  │                               │  │
│  │    ✨ Tasks Added! ✨        │  │
│  │                               │  │
│  │ 4 new tasks created:          │  │
│  │ • Math Class (recurring)      │  │
│  │ • Math Study (recurring)      │  │
│  │ • English Class (recurring)   │  │
│  │ • English Study (recurring)   │  │
│  │                               │  │
│  │   [Done - Back to Home]       │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
        │
        ▼
    Home page updated with
    new tasks visible!
```

---

## Code Changes Diagram

### File: lib/src/presentation/pages/home.dart

```dart
// BEFORE:
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ... other imports ...
// ❌ No ScheduleImportPage import

class Home extends ConsumerStatefulWidget {
  // ... code ...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... code ...
      appBar: AppBar(
        // ... code ...
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: const CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/button_bg.png'),
              ),
            ),
          ),
        ],
      ),
      // ... code ...
    );
  }
}

// AFTER:
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ... other imports ...
import 'schedule_import/schedule_import_page.dart';  // ✅ NEW IMPORT

class Home extends ConsumerStatefulWidget {
  // ... code ...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... code ...
      appBar: AppBar(
        // ... code ...
        actions: [
          // ✅ NEW: Schedule Import button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Tooltip(
                message: 'Import Schedule',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScheduleImportPage(),
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_month_outlined,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // Profile button (unchanged)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: const CircleAvatar(
                radius: 22,
                backgroundImage: AssetImage('assets/button_bg.png'),
              ),
            ),
          ),
        ],
      ),
      // ... code ...
    );
  }
}
```

---

## App Bar Layout

### Calendar Button Position

```
┌─────────────────────────────────────────────────┐
│ Home  Focus  Stats  Profile       [📅] [👤]    │
│                                    ▲    ▲       │
│                         NEW ────────┘    │       │
│                         Calendar      Profile    │
│                         Icon Button    (Old)     │
└─────────────────────────────────────────────────┘

Visual Hierarchy:
- 8px padding between calendar and profile buttons
- 16px padding on right edge (matches original)
- Icons same size (24px)
- Same color treatment (white70)
- Tooltip on hover: "Import Schedule"
```

---

## Navigation Flow

### Complete App Navigation

```
┌─────────────────────────────────┐
│      MAIN PAGE (Bottom Nav)     │
│  [Home] [Focus] [Stats] [Prof]  │
└────────────────┬────────────────┘
                 │
                 ├─────────┬──────────┬──────────┐
                 │         │          │          │
                 ▼         ▼          ▼          ▼
             ┌─────┐  ┌────────┐ ┌───────┐ ┌────────┐
             │Home │  │ Focus  │ │ Stats │ │Profile │
             └────┬┘  └────────┘ └───────┘ └────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
        ▼ (New)             ▼ (Existing)
    ┌────────────────┐   ┌─────────────┐
    │Schedule Import │   │Add Task Page│
    │   (Wizard)     │   │             │
    └────────────────┘   └─────────────┘
        │
        ├─ Step 1: Image Picker
        │
        ├─ Step 2: Loading
        │
        ├─ Step 3A: Timetable Adjustment
        │  OR
        ├─ Step 3B: Exam Adjustment
        │
        ├─ Step 4: Preview
        │
        └─ Step 5: Success
```

---

## Technology Stack

### Layers & Components

```
PRESENTATION LAYER
├── Pages
│   ├── main_page.dart (Navigation)
│   │   └─ Home (with new Calendar button)
│   │       └─ [📅] ─ NEW ACCESS POINT
│   │
│   └── schedule_import/
│       ├── schedule_import_page.dart (Image picker)
│       ├── schedule_loading_page.dart (AI processing)
│       ├── timetable_adjustment_page.dart (Path A)
│       ├── exam_adjustment_page.dart (Path B)
│       ├── schedule_preview_page.dart (Confirmation)
│       └── schedule_import_success_page.dart (Success)
│
├── Providers
│   └── schedule_import_notifier.dart (State machine)
│       └── scheduleImportProvider (Riverpod state)
│
└── State Models
    └── schedule_import_state.dart (Enum + State class)

DOMAIN LAYER
├── Entities
│   ├── extracted_class.dart
│   ├── extracted_exam.dart
│   ├── schedule_type.dart
│   └── schedule_import_result.dart
│
├── Repositories (Abstract)
│   └── schedule_import_repository.dart
│
└── Use Cases
    ├── extract_schedule_from_image_use_case.dart
    ├── generate_weekly_tasks_use_case.dart
    └── generate_exam_prep_tasks_use_case.dart

DATA LAYER
├── Data Sources
│   └── gemini_schedule_import_datasource.dart
│       └── Firebase Vertex AI (secure)
│
├── DTOs
│   ├── schedule_import_result_dto.dart
│   ├── extracted_class_dto.dart
│   └── extracted_exam_dto.dart
│
├── Mappers
│   └── (Conversion: DTO → Entity)
│
└── Repositories (Implementation)
    └── schedule_import_repository_impl.dart

CORE
└── service_locator.dart
    ├── Registers data sources (singletons)
    ├── Registers repositories (singletons)
    ├── Registers use cases (factories)
    └── Initializes DI on app startup
```

---

## State Machine Diagram

### ScheduleImportStep Flow

```
                    ┌─────────────────┐
                    │   imagePicker   │ ◄── START
                    └────────┬────────┘
                             │
                    User picks image ✅
                             │
                             ▼
                    ┌─────────────────┐
                    │   aiLoading     │
                    │                 │
                    │  ⏳ Processing   │
                    │     Schedule    │
                    └────────┬────────┘
                             │
                   AI finishes extraction ✅
                             │
                    ┌────────┴────────┐
                    │                 │
         Type == timetable    Type == exam
                    │                 │
                    ▼                 ▼
           ┌──────────────────┐  ┌───────────────┐
           │timetableAdjust   │  │  examAdjust   │
           │                  │  │               │
           │ User toggles:    │  │ User rates:   │
           │ • Homework?      │  │ • Difficulty  │
           │ • Study hours    │  │  (E/M/H)      │
           └────────┬─────────┘  └────────┬──────┘
                    │                    │
         User continues ✅   User continues ✅
                    │                    │
                    └────────┬───────────┘
                             │
                             ▼
                    ┌─────────────────┐
                    │    preview      │
                    │                 │
                    │ Show generated  │
                    │ tasks (read-only)
                    └────────┬────────┘
                             │
                    User confirms ✅
                             │
                             ▼
                    ┌─────────────────┐
                    │     saving      │
                    │                 │
                    │ Writing to DB   │
                    └────────┬────────┘
                             │
              ┌──────────────┬──────────────┐
              │                             │
          Success ✅                    Error ❌
              │                             │
              ▼                             ▼
      ┌────────────────┐        ┌────────────────────┐
      │    success     │        │      error         │
      │                │        │                    │
      │ ✨ Done! ✨   │        │ Show error message │
      │ 4 tasks added  │        │ [Retry] [Cancel]   │
      │ [Back to Home] │        └────────┬───────────┘
      └────────┬───────┘                 │
               │            ┌────────────┘
               │            │
               ▼            ▼ Retry/back
         Back to Home    imagePicker
         Tasks visible
             in list
```

---

## Summary of Changes

| File | Change | Type | Impact |
|------|--------|------|--------|
| `home.dart` | Added import | Code | Required for button |
| `home.dart` | Added Calendar button | Code | UI now accessible |
| `home.dart` | Button navigation | Code | Opens wizard |
| Documentation | 4 new guides | Docs | Maintenance + security |

**Total Lines Changed:** ~40 (minimal, surgical change)  
**Breaking Changes:** None  
**Dependencies Added:** None  
**Security Issues Fixed:** None (wasn't an issue, just missing UI)  

---

## Testing the Fix

### Manual Testing Steps

1. **Launch the app**
   ```bash
   flutter run
   ```

2. **Navigate to Home page**
   - Should see calendar icon (📅) in top-right AppBar

3. **Tap the calendar icon**
   - Should navigate to ScheduleImportPage
   - Should see image picker UI

4. **Pick an image or camera**
   - Should show preview

5. **Tap Continue**
   - Should show loading screen
   - Should call Gemini API

6. **Follow wizard steps**
   - Adjust classes/exams
   - Review tasks
   - Save to Firestore

7. **Verify back on Home**
   - Should see new tasks in task list
   - Should be ready for next action

### Automated Testing

```dart
// Test: Calendar button exists and is tappable
testWidgets('Schedule import button is accessible', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
  
  // Verify button exists
  expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
  
  // Tap button
  await tester.tap(find.byIcon(Icons.calendar_month_outlined));
  await tester.pumpAndSettle();
  
  // Verify navigation
  expect(find.byType(ScheduleImportPage), findsOneWidget);
});
```

---

## Conclusion

The fix is:
- ✅ **Minimal** - Only ~40 lines changed
- ✅ **Safe** - No breaking changes
- ✅ **Effective** - Feature now accessible
- ✅ **Professional** - Follows Material Design
- ✅ **Documented** - Complete guides provided

**The Schedule Import feature is now fully operational! 🎉**


