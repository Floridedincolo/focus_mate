# 📚 COMPREHENSIVE GUIDE - 38 New Files Explained

## Quick Navigation

This document contains detailed explanations of all 38 Dart files added during the refactoring.

**Choose your format:**

1. **DETAILED_FILE_EXPLANATIONS.md** - Deep dive into each file individually
   - Role, what it contains, who uses it, maintenance notes
   - Best for: Understanding the purpose of each file
   - Read time: 1 hour

2. **FILE_RELATIONSHIPS.md** - How files connect and interact
   - Data flow diagrams, dependency wiring, patterns
   - Best for: Understanding the big picture architecture
   - Read time: 30 minutes

3. **This file (GUIDE)** - Quick reference and shortcuts
   - File summary table, quick lookup, decision trees
   - Best for: Quick lookup when you need to find something
   - Read time: 10 minutes

---

## 📋 Quick File Lookup Table

### By Purpose

| Purpose | Files | Location |
|---------|-------|----------|
| **Data Models** | Task, TaskStatus, BlockedApp, InstalledApplication | `lib/src/domain/entities/` |
| **API Contracts** | TaskRepository, AppManagerRepository, BlockManagerRepository, AccessibilityRepository | `lib/src/domain/repositories/` |
| **Business Rules** | task_usecases, app_usecases, accessibility_usecases | `lib/src/domain/usecases/` |
| **Data Converters** | TaskMapper, AppMapper | `lib/src/data/mappers/` |
| **Network Models** | TaskDTO, AppDTO | `lib/src/data/dtos/` |
| **Data Interfaces** | task_data_source, app_data_source, accessibility_data_source | `lib/src/data/datasources/` |
| **Implementations** | firestore_task_datasource, native_app_datasource, shared_preferences_datasource, method_channel_accessibility_datasource | `lib/src/data/datasources/implementations/` |
| **Concrete Repos** | task_repository_impl, app_repository_impl, accessibility_repository_impl | `lib/src/data/repositories/` |
| **UI State** | task_providers, app_providers, accessibility_providers | `lib/src/presentation/providers/` |
| **Dependency Wiring** | service_locator | `lib/src/core/` |

---

## 🎯 Quick Decision Tree - What File Do I Need?

### "I need to add a new feature/use case"
1. Create domain entity in `lib/src/domain/entities/`
2. Create repository interface in `lib/src/domain/repositories/`
3. Create use case in `lib/src/domain/usecases/`
4. Create data source interface in `lib/src/data/datasources/`
5. Create data source implementation in `lib/src/data/datasources/implementations/`
6. Create mapper in `lib/src/data/mappers/`
7. Create repository impl in `lib/src/data/repositories/`
8. Create providers in `lib/src/presentation/providers/`
9. Register in `lib/src/core/service_locator.dart`
10. Use in `lib/pages/` or `lib/src/presentation/pages/`

**Files to use:** FEATURE_TEMPLATE.md (it has step-by-step guide)

---

### "I need to understand how data flows"
1. Look at FILE_RELATIONSHIPS.md → "Data Transformation Flow" section
2. Pick your use case (Task, App, or Accessibility)
3. Trace the flow from UI → Providers → Use Case → Repository → Data Source → External

---

### "I need to change how data is persisted"
1. Find the data source implementation (e.g., `firestore_task_datasource.dart`)
2. Change the Firestore code there
3. No other files need to change! (Repository, Use Case, UI all stay the same)

**Why?** Because of Repository Pattern - abstraction shields upper layers

---

### "I need to test something"
1. For business logic → Mock repository, test use case
2. For data access → Mock data source, test repository
3. For UI → Mock provider, test widget
4. See FILE_RELATIONSHIPS.md → "Testing Points" section

---

### "The app is crashing or hanging"
1. Check `lib/src/data/datasources/implementations/method_channel_accessibility_datasource.dart`
   - All MethodChannel calls have 2s timeout
   - All methods have try-catch with safe defaults

2. Check `lib/src/core/service_locator.dart`
   - SharedPreferences init is async non-blocking
   - All dependencies registered properly

3. Check `lib/src/presentation/providers/accessibility_providers.dart`
   - All providers have error handling
   - Safe defaults prevent crashes

---

## 📊 Files by Layer

### DOMAIN LAYER (Pure Business Logic - No Frameworks)

```
lib/src/domain/
├��─ entities/              (4 files - data models)
│   ├── task.dart
│   ├── task_status.dart
│   ├── installed_application.dart
│   └── blocked_app.dart
│
├── repositories/          (4 files - interfaces/contracts)
│   ├── task_repository.dart
│   ├── app_manager_repository.dart
│   ├── block_manager_repository.dart
│   └── accessibility_repository.dart
│
├── usecases/             (3 files - business rules)
│   ├── task_usecases.dart (5 use cases)
│   ├── app_usecases.dart (7 use cases)
│   └── accessibility_usecases.dart (6 use cases)
│
└── errors/               (1 file - exceptions)
    └── domain_errors.dart
```

**Total: 12 files**
**Purpose:** Pure business logic, testable, framework-agnostic

---

### DATA LAYER (Implementation & Data Access)

```
lib/src/data/
├── dtos/                 (2 files - external data formats)
│   ├── task_dto.dart
│   └── app_dto.dart
│
├── mappers/              (2 files - conversions)
│   ├── task_mapper.dart
│   └── app_mapper.dart
│
├── datasources/          (3 files - interfaces)
│   ├── task_data_source.dart
│   ├── app_data_source.dart
│   └── accessibility_data_source.dart
│
├── datasources/
│   └── implementations/  (4 files - implementations)
│       ├── firestore_task_datasource.dart
│       ├── native_app_datasource.dart
│       ├── shared_preferences_datasource.dart
│       └── method_channel_accessibility_datasource.dart
│
└── repositories/         (3 files - concrete repository impls)
    ├── task_repository_impl.dart
    ├── app_repository_impl.dart
    └── accessibility_repository_impl.dart
```

**Total: 14 files**
**Purpose:** Implement domain contracts, access external data sources

---

### PRESENTATION LAYER (UI State Management)

```
lib/src/presentation/
└── providers/            (3 files - Riverpod state)
    ├── task_providers.dart (8 providers)
    ├── app_providers.dart (10+ providers)
    └── accessibility_providers.dart (8 providers, with error handling)
```

**Total: 3 files**
**Purpose:** Reactive state management for UI consumption

---

### CORE LAYER (Infrastructure)

```
lib/src/core/
└── service_locator.dart  (1 file - DI setup)
```

**Total: 1 file**
**Purpose:** Single point to wire and manage all dependencies

---

### SUMMARY BY LAYER

| Layer | Files | LOC | Purpose |
|-------|-------|-----|---------|
| Domain | 12 | ~400 | Pure business logic |
| Data | 14 | ~1500 | Data access & persistence |
| Presentation | 3 | ~200 | UI state management |
| Core | 1 | ~400 | Dependency injection |
| **TOTAL** | **38** | **~2,500** | **Full stack** |

---

## 🔗 Key Relationships at a Glance

### Files That Work Together

**Task Management Trio:**
- `task.dart` (entity) + `task_dto.dart` (DTO) + `task_mapper.dart` (conversion)
- `task_repository.dart` (interface) + `task_repository_impl.dart` (impl)
- `task_usecases.dart` (5 business actions)
- `firestore_task_datasource.dart` (Firestore access)
- `task_providers.dart` (UI state)

**App Blocking Trio:**
- `blocked_app.dart` (entity) + `app_dto.dart` (DTO) + `app_mapper.dart` (conversion)
- `block_manager_repository.dart` (interface) + `app_repository_impl.dart` (impl)
- `app_usecases.dart` (7 business actions)
- `shared_preferences_datasource.dart` (local storage)
- `native_app_datasource.dart` (native list of apps)
- `app_providers.dart` (UI state)

**Accessibility Trio:**
- `accessibility_repository.dart` (interface) + `accessibility_repository_impl.dart` (impl)
- `accessibility_usecases.dart` (6 business actions)
- `method_channel_accessibility_datasource.dart` (native calls with timeout)
- `accessibility_data_source.dart` (interface)
- `accessibility_providers.dart` (UI state with error handling)

**Support Files:**
- `domain_errors.dart` (exceptions) - used everywhere
- `service_locator.dart` (DI) - registers everything
- `task_data_source.dart` (interface) - implemented by firestore/memory
- `app_data_source.dart` (interface) - implemented by native/shared_prefs
- `accessibility_data_source.dart` (interface) - implemented by method_channel

---

## 📖 How to Read the Detailed Explanations

### Option 1: Deep Dive (Recommended for new team members)

**Read in this order:**
1. DETAILED_FILE_EXPLANATIONS.md - Part 1: Domain Layer (15 min)
2. DETAILED_FILE_EXPLANATIONS.md - Part 2: Data Layer (20 min)
3. DETAILED_FILE_EXPLANATIONS.md - Part 3: Presentation Layer (15 min)
4. FILE_RELATIONSHIPS.md - "Fluxul General" + your subsystem (15 min)
5. FILE_RELATIONSHIPS.md - "Dependency Injection Wiring" (10 min)

**Total: ~1.5 hours** → You'll understand everything

---

### Option 2: Focused Deep Dive (For specific feature)

**If you're adding a task-related feature:**
1. DETAILED_FILE_EXPLANATIONS.md - Task files (10 min)
2. FILE_RELATIONSHIPS.md - Task Management Flow (5 min)
3. FEATURE_TEMPLATE.md - Follow the 11 steps (1-2 hours implementation)

**If you're working on app blocking:**
1. DETAILED_FILE_EXPLANATIONS.md - App Blocking files (10 min)
2. FILE_RELATIONSHIPS.md - App Blocking Flow (5 min)
3. FEATURE_TEMPLATE.md - Follow the 11 steps (1-2 hours implementation)

**If you're fixing accessibility issues:**
1. DETAILED_FILE_EXPLANATIONS.md - Accessibility files (10 min)
2. FILE_RELATIONSHIPS.md - Accessibility Flow (5 min)
3. FILE_RELATIONSHIPS.md - Error Handling & Safety (10 min)

---

### Option 3: Quick Reference (When you just need to find something)

1. This file (GUIDE) - Find your use case
2. Use the decision tree or file lookup table
3. Go directly to that section in DETAILED_FILE_EXPLANATIONS.md
4. Jump to FILE_RELATIONSHIPS.md if you need context

---

## 🎓 Learning Paths

### Beginner (New to the codebase)

**Week 1:**
- Day 1: Read CHANGES_SUMMARY.md (5 min)
- Day 2: Read ARCHITECTURE_VISUAL_GUIDE.md (15 min)
- Day 3: Read DETAILED_FILE_EXPLANATIONS.md - Domain section (15 min)
- Day 4: Read DETAILED_FILE_EXPLANATIONS.md - Data section (20 min)
- Day 5: Read DETAILED_FILE_EXPLANATIONS.md - Presentation section (15 min)

**Week 2:**
- Read FILE_RELATIONSHIPS.md - Full (30 min)
- Read FEATURE_TEMPLATE.md (20 min)
- Try adding a simple feature following template (2-3 hours)

**Total: ~10 hours** → You'll be productive

---

### Intermediate (Understands architecture basics)

**Session 1 (1 hour):**
- Skim DETAILED_FILE_EXPLANATIONS.md - find relevant sections (15 min)
- Read FILE_RELATIONSHIPS.md - relevant subsystem (15 min)
- Read FEATURE_TEMPLATE.md (20 min)

**Session 2 (2-3 hours):**
- Implement new feature following template

---

### Advanced (Wants to optimize/refactor)

1. Read FILE_RELATIONSHIPS.md - "Testing Points" (10 min)
2. Read FILE_RELATIONSHIPS.md - "Key Design Patterns" (15 min)
3. Review error handling implementation (15 min)
4. Review DI wiring (10 min)
5. Optimize based on findings (varies)

---

## ❓ FAQ - Common Questions

### Q: "Where do I add a new task property?"
**A:** 
1. Add to `Task` entity in `task.dart`
2. Add to `TaskDTO` in `task_dto.dart`
3. Update `TaskMapper` in `task_mapper.dart`
4. Update Firestore in `firestore_task_datasource.dart`
5. Update UI in `lib/pages/` or providers

**Files:** 5 files to touch

---

### Q: "How do I mock a repository in tests?"
**A:** 
1. Create `FakeTaskRepository implements TaskRepository`
2. Implement all methods with test behavior
3. In `service_locator.dart` during test setup: `getIt.registerSingleton<TaskRepository>(FakeTaskRepository())`
4. Now all use cases get your fake!

**Files:** service_locator.dart + test file

---

### Q: "Why does MethodChannel have a timeout?"
**A:** 
Because native code can be slow or unresponsive. 2-second timeout prevents the app from freezing.
See `method_channel_accessibility_datasource.dart` for implementation.

---

### Q: "Can I swap Firestore for REST API?"
**A:** 
Yes! Only change `firestore_task_datasource.dart`. The whole stack above it stays the same.

That's the power of the Repository Pattern.

---

### Q: "How do I know if a provider is cached?"
**A:** 
Most Riverpod providers auto-cache. See `app_providers.dart` - it has a `availableAppsProvider` that's computed/cached from other providers.

---

### Q: "What's the difference between a DTO and an Entity?"
**A:** 
- **Entity:** Domain representation (pure, business logic)
- **DTO:** External representation (how Firestore/API sends it)

Mappers convert between them.

---

### Q: "Can I call a use case from a widget directly?"
**A:** 
You can, but shouldn't. Use providers instead:
- Provider is testable (can override for tests)
- Provider auto-caches results
- Provider rebuilds UI automatically

---

## ✅ Checklist - Files You Need to Know

### Essential (read first)
- [ ] task_repository.dart (interface)
- [ ] task_usecases.dart (business logic)
- [ ] task_repository_impl.dart (implementation)
- [ ] task_providers.dart (UI usage)
- [ ] service_locator.dart (wiring)

### Important (read next)
- [ ] domain_errors.dart (exceptions)
- [ ] task_mapper.dart (conversions)
- [ ] firestore_task_datasource.dart (persistence)
- [ ] FILE_RELATIONSHIPS.md (big picture)

### Reference (look up as needed)
- [ ] All entity files
- [ ] All DTO files
- [ ] All datasource files
- [ ] All provider files
- [ ] DETAILED_FILE_EXPLANATIONS.md

---

## 🚀 Ready to Code?

**To add a new feature:**
1. Open FEATURE_TEMPLATE.md
2. Follow the 11 steps
3. Reference this file if you get stuck

**To fix a bug:**
1. Find relevant file in file lookup table
2. Read its section in DETAILED_FILE_EXPLANATIONS.md
3. Check FILE_RELATIONSHIPS.md for context
4. Make your change

**To understand something:**
1. Search for keyword in DETAILED_FILE_EXPLANATIONS.md
2. Read that file's explanation
3. Jump to FILE_RELATIONSHIPS.md for visual flow

---

## 📞 Quick Reference Links

**Inside this documentation:**
- DETAILED_FILE_EXPLANATIONS.md - Every file explained in detail
- FILE_RELATIONSHIPS.md - How files connect and interact
- FEATURE_TEMPLATE.md - Step-by-step guide to add features

**Other key docs:**
- MODULAR_ARCHITECTURE_GUIDE.md - Technical deep dive
- ARCHITECTURE_VISUAL_GUIDE.md - Diagrams and flows
- START_HERE.md - Orientation guide

---

**You now have 3 documents to understand all 38 new files!** 📚

Choose your reading path above and get started! 🚀


