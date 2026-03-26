import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/service_locator.dart';
import '../../data/datasources/transit_route_service.dart';
import '../../data/datasources/implementations/google_transit_route_service.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/meeting_location.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/repeat_type.dart';
import '../../domain/extensions/task_filter.dart';
import '../providers/task_providers.dart';
import '../widgets/datepicker.dart';
import '../widgets/choose_repeating.dart';
import '../widgets/time_picker.dart';
import '../widgets/reminder_picker.dart';
import '../widgets/location_autocomplete_field.dart';

/// Unified Add / Edit task screen.
///
/// Pass [existingTask] to enter **edit mode**; leave it `null` for add mode.
class AddTaskMenu extends ConsumerStatefulWidget {
  final Task? existingTask;

  const AddTaskMenu({super.key, this.existingTask});

  @override
  ConsumerState<AddTaskMenu> createState() => _AddTaskMenuState();
}

class _AddTaskMenuState extends ConsumerState<AddTaskMenu> {
  // ── Controllers ──────────────────────────────────────────────────────
  late final TextEditingController _titleController;

  // ── State ────────────────────────────────────────────────────────────
  bool _oneTime = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _startDate;
  final List<Reminder> _reminders = [];
  RepeatType? _repeatType = RepeatType.daily;
  Map<String, bool> _repeatDays = {};
  bool _saving = false;

  // ── Location state (filled by LocationAutocompleteField) ─────────────
  String? _locationName;
  double? _locationLatitude;
  double? _locationLongitude;
  bool _locationTextInitialized = false;

  bool get _isEditing => widget.existingTask != null;

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    _titleController = TextEditingController(text: t?.title ?? '');

    if (t != null) {
      _oneTime = t.oneTime;
      _startTime = t.startTime;
      _endTime = t.endTime;
      _startDate = t.startDate;
      _reminders.addAll(t.reminders);
      _repeatType = t.repeatType ?? RepeatType.daily;
      _repeatDays = Map.of(t.days);
      _locationName = t.locationName;
      _locationLatitude = t.locationLatitude;
      _locationLongitude = t.locationLongitude;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ── Submit ───────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return _showError('Task title is required');
    if (_startDate == null) return _showError('Please select a date');
    if (!_oneTime) {
      if (_repeatType == null) return _showError('Choose a repeat type');
      if (_repeatType == RepeatType.custom &&
          !_repeatDays.containsValue(true)) {
        return _showError('Select at least one day');
      }
      if (_startTime == null || _endTime == null) {
        return _showError('Start and End time are required');
      }
    }

    final task = Task(
      id: widget.existingTask?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      oneTime: _oneTime,
      startDate: _startDate!,
      startTime: _startTime,
      endTime: _endTime,
      reminders: _reminders,
      repeatType: _oneTime ? null : _repeatType,
      days: _oneTime ? {} : _repeatDays,
      archived: widget.existingTask?.archived ?? false,
      streak: widget.existingTask?.streak ?? 0,
      locationName:
          _locationName != null && _locationName!.isNotEmpty ? _locationName : null,
      locationLatitude: _locationLatitude,
      locationLongitude: _locationLongitude,
    );

    // ── Smart Transit Warning ─────────────────────────────────────────
    final shouldSave = await _checkTransitWarning(task);
    if (!shouldSave || !mounted) return;

    // ── Save ──────────────────────────────────────────────────────────
    await _saveTask(task);
  }

  /// Persists the task and shows a success message.
  Future<void> _saveTask(Task task) async {
    setState(() => _saving = true);
    try {
      await ref.read(saveTaskProvider(task).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Task updated successfully!'
                : 'Task created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Returns `true` if the task should be saved (either no conflict, or the
  /// user chose "Save anyway"). Returns `false` if the user cancelled.
  Future<bool> _checkTransitWarning(Task newTask) async {
    if (newTask.startTime == null || _startDate == null) return true;

    List<Task> allTasks;
    try {
      allTasks = await ref
          .read(tasksStreamProvider.future)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      return true;
    }

    final dayTasks = allTasks
        .where((t) =>
            t.id != newTask.id &&
            t.occursOn(_startDate!) &&
            t.startTime != null &&
            t.endTime != null)
        .toList();

    if (dayTasks.isEmpty) return true;

    final newStart = newTask.startTime!.hour * 60 + newTask.startTime!.minute;
    final newEnd = newTask.endTime != null
        ? newTask.endTime!.hour * 60 + newTask.endTime!.minute
        : newStart + 1;

    // ── 1. Check for time overlaps ───────────────────────────────────
    for (final t in dayTasks) {
      final tStart = t.startTime!.hour * 60 + t.startTime!.minute;
      final tEnd = t.endTime!.hour * 60 + t.endTime!.minute;
      final overlaps = newStart < tEnd && tStart < newEnd;
      if (overlaps) {
        if (!mounted) return false;
        return await _showOverlapDialog(t, newTask);
      }
    }

    // ── 2. Check transit time for adjacent tasks ──────────────────────
    if (newTask.locationLatitude == null || newTask.locationLongitude == null) {
      return true;
    }

    final newLoc = MeetingLocation(
      name: newTask.locationName ?? '',
      latitude: newTask.locationLatitude,
      longitude: newTask.locationLongitude,
    );

    final legs = <_TransitLeg>[];

    // ── 2a. Closest PRECEDING task ───────────────────────────────────
    Task? prevTask;
    int prevEndMinutes = -1;

    for (final t in dayTasks) {
      final tEnd = t.endTime!.hour * 60 + t.endTime!.minute;
      if (tEnd <= newStart &&
          tEnd > prevEndMinutes &&
          t.locationLatitude != null &&
          t.locationLongitude != null) {
        prevTask = t;
        prevEndMinutes = tEnd;
      }
    }

    if (prevTask != null) {
      final gapMinutes = newStart - prevEndMinutes;
      final origin = MeetingLocation(
        name: prevTask.locationName ?? '',
        latitude: prevTask.locationLatitude,
        longitude: prevTask.locationLongitude,
      );
      final modes = await _buildTransitWarning(
        origin: origin, destination: newLoc, gapMinutes: gapMinutes);
      if (modes != null) {
        legs.add(_TransitLeg(
          fromTitle: prevTask.title, toTitle: newTask.title,
          gapMinutes: gapMinutes, modes: modes));
      }
    }

    // ── 2b. Closest FOLLOWING task ───────────────────────────────────
    Task? nextTask;
    int nextStartMinutes = 99999;

    for (final t in dayTasks) {
      final tStart = t.startTime!.hour * 60 + t.startTime!.minute;
      if (tStart >= newEnd &&
          tStart < nextStartMinutes &&
          t.locationLatitude != null &&
          t.locationLongitude != null) {
        nextTask = t;
        nextStartMinutes = tStart;
      }
    }

    if (nextTask != null) {
      final gapMinutes = nextStartMinutes - newEnd;
      final nextLoc = MeetingLocation(
        name: nextTask.locationName ?? '',
        latitude: nextTask.locationLatitude,
        longitude: nextTask.locationLongitude,
      );
      final modes = await _buildTransitWarning(
        origin: newLoc, destination: nextLoc, gapMinutes: gapMinutes);
      if (modes != null) {
        legs.add(_TransitLeg(
          fromTitle: newTask.title, toTitle: nextTask.title,
          gapMinutes: gapMinutes, modes: modes));
      }
    }

    if (legs.isEmpty) return true;
    if (!mounted) return false;
    return await _showTransitDialog(legs: legs);
  }

  // ── Transit warning helpers ────────────────────────────────────────────

  Future<List<_TransitModeResult>?> _buildTransitWarning({
    required MeetingLocation origin,
    required MeetingLocation destination,
    required int gapMinutes,
  }) async {
    final transitService = getIt<TransitRouteService>();
    final distKm = GoogleTransitRouteService.haversineKm(
      origin.latitude!, origin.longitude!,
      destination.latitude!, destination.longitude!,
    );

    final results = <_TransitModeResult>[];
    bool anyExceeds = false;

    // DRIVE
    try {
      final raw = await transitService.getTransitTimeMinutes(
        origin: origin, destination: destination, mode: 'DRIVE');
      if (raw != null) {
        final total = raw + GoogleTransitRouteService.parkingOverheadMinutes;
        final exceeds = total > gapMinutes;
        if (exceeds) anyExceeds = true;
        results.add(_TransitModeResult(
          icon: Icons.directions_car, label: 'Drive', minutes: total,
          detail: '~${raw}min + ~${GoogleTransitRouteService.parkingOverheadMinutes}min parking',
          exceeds: exceeds));
      }
    } catch (_) {}

    // WALK (skip if > 5 km)
    if (distKm <= 5.0) {
      try {
        final raw = await transitService.getTransitTimeMinutes(
          origin: origin, destination: destination, mode: 'WALK');
        if (raw != null) {
          final exceeds = raw > gapMinutes;
          if (exceeds) anyExceeds = true;
          results.add(_TransitModeResult(
            icon: Icons.directions_walk, label: 'Walk', minutes: raw,
            detail: '~${distKm.toStringAsFixed(1)} km', exceeds: exceeds));
        }
      } catch (_) {}
    }

    // TRANSIT
    try {
      final raw = await transitService.getTransitTimeMinutes(
        origin: origin, destination: destination, mode: 'TRANSIT');
      if (raw != null) {
        final exceeds = raw > gapMinutes;
        if (exceeds) anyExceeds = true;
        results.add(_TransitModeResult(
          icon: Icons.directions_bus, label: 'Transit', minutes: raw,
          detail: 'bus / tram', exceeds: exceeds));
      }
    } catch (_) {}

    if (!anyExceeds || results.isEmpty) return null;
    return results;
  }

  Future<bool> _showOverlapDialog(Task existing, Task newTask) async {
    final existStart = existing.startTime!.format(context);
    final existEnd = existing.endTime!.format(context);
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.schedule, color: Colors.redAccent, size: 48),
        title: const Text('Time Overlap Detected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'This task overlaps with "${existing.title}" '
          '($existStart – $existEnd).\n\n'
          'Are you sure you want to save it anyway?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Save Anyway')),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<bool> _showTransitDialog({required List<_TransitLeg> legs}) async {
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 48),
        title: Text(
          legs.length > 1 ? 'Multiple Schedule Conflicts' : 'Tight Schedule Warning',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < legs.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                ],
                Text('"${legs[i].fromTitle}" → "${legs[i].toTitle}"',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text('Available gap', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    const Spacer(),
                    Text('${legs[i].gapMinutes} min',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 8),
                ...legs[i].modes.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: (m.exceeds ? Colors.redAccent : Colors.green).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: (m.exceeds ? Colors.redAccent : Colors.green).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(m.icon, color: m.exceeds ? Colors.redAccent : Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(m.detail, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ])),
                      Text('${m.minutes} min',
                          style: TextStyle(color: m.exceeds ? Colors.redAccent : Colors.green,
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(m.exceeds ? Icons.cancel_rounded : Icons.check_circle_rounded,
                          color: m.exceeds ? Colors.redAccent : Colors.green, size: 18),
                    ]),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('Save Anyway')),
        ],
      ),
    );
    return proceed ?? false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  // ── Reminders ────────────────────────────────────────────────────────

  Future<void> _addReminder() async {
    final reminder = await showModalBottomSheet<Reminder>(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      builder: (_) => const ReminderPickerDialog(),
    );
    if (reminder != null) setState(() => _reminders.add(reminder));
  }

  void _deleteReminder(int index) =>
      setState(() => _reminders.removeAt(index));

  // ── UI Constants ─────────────────────────────────────────────────────

  static const _bg = Color(0xFF0D0D0D);
  static const _card = Color(0xFF1A1A1A);
  static const _accent = Colors.blueAccent;

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.white38) : null,
      filled: true,
      fillColor: _card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Task' : 'New Task',
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTypeToggle(),
              const SizedBox(height: 20),

              _sectionLabel('TITLE'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(hint: 'Enter task title', prefixIcon: Icons.edit_outlined),
              ),
              const SizedBox(height: 20),

              _sectionLabel('LOCATION'),
              const SizedBox(height: 8),
              LocationAutocompleteField(
                initialLocationName: widget.existingTask?.locationName,
                decoration: _inputDecoration(hint: 'Search for a place…', prefixIcon: Icons.location_on_outlined),
                onLocationSelected: (MeetingLocation? loc) {
                  setState(() {
                    _locationName = loc?.name;
                    _locationLatitude = loc?.latitude;
                    _locationLongitude = loc?.longitude;
                  });
                },
                onTextChanged: (text) {
                  if (!_locationTextInitialized) {
                    _locationTextInitialized = true;
                    if (_isEditing && widget.existingTask?.locationName != null) return;
                  }
                  _locationName = text.trim().isNotEmpty ? text.trim() : null;
                  _locationLatitude = null;
                  _locationLongitude = null;
                },
              ),
              const SizedBox(height: 20),

              _sectionLabel('DATE'),
              const SizedBox(height: 8),
              DatePickerField(
                initialDate: _startDate,
                onDateSelected: (date) => _startDate = date,
              ),
              const SizedBox(height: 20),

              if (!_oneTime) ...[
                _sectionLabel('REPEAT'),
                const SizedBox(height: 8),
                ChooseRepeating(
                  repeatType: _repeatType ?? RepeatType.daily,
                  d: _repeatDays,
                  onRepeatChanged: (type, days) => setState(() {
                    _repeatType = type;
                    _repeatDays = days;
                  }),
                ),
                const SizedBox(height: 20),
              ],

              _sectionLabel('TIME'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TimePicker(label: 'Start', initialTime: _startTime, onTimeSelected: (t) => _startTime = t)),
                const SizedBox(width: 12),
                Expanded(child: TimePicker(label: 'End', initialTime: _endTime, onTimeSelected: (t) => _endTime = t)),
              ]),
              const SizedBox(height: 20),

              _sectionLabel('REMINDERS'),
              const SizedBox(height: 8),
              ..._reminders.asMap().entries.map(_buildReminderTile),
              const SizedBox(height: 8),
              _buildAddReminderButton(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_isEditing ? 'Save Changes' : 'Create Task',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  // ── Extracted widgets ──────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(
      color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.8));
  }

  Widget _buildTypeToggle() {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        _toggleButton(label: 'One-time', icon: Icons.event_outlined, selected: _oneTime,
            onTap: () => setState(() => _oneTime = true)),
        _toggleButton(label: 'Recurring', icon: Icons.repeat, selected: !_oneTime,
            onTap: () => setState(() => _oneTime = false)),
      ]),
    );
  }

  Widget _toggleButton({
    required String label, required IconData icon,
    required bool selected, required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400, fontSize: 15)),
          ]),
        ),
      ),
    );
  }

  Widget _buildReminderTile(MapEntry<int, Reminder> entry) {
    final i = entry.key;
    final r = entry.value;
    final days = r.days.entries.where((d) => d.value).map((d) => d.key).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: [
        const Icon(Icons.notifications_active_outlined, color: Colors.amber, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.time.format(context), style: const TextStyle(color: Colors.white, fontSize: 15)),
          if (days.isNotEmpty) Text(days.join(', '), style: const TextStyle(color: Colors.white38, fontSize: 12)),
          if (r.message.isNotEmpty) Text(r.message, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        IconButton(icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: () => _deleteReminder(i)),
      ]),
    );
  }

  Widget _buildAddReminderButton() {
    return GestureDetector(
      onTap: _addReminder,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), style: BorderStyle.solid),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_alert_outlined, color: Colors.white54, size: 20),
          SizedBox(width: 8),
          Text('Add Reminder', style: TextStyle(color: Colors.white54, fontSize: 15)),
        ]),
      ),
    );
  }
}

/// Groups transit mode results for one leg (e.g. prevTask → newTask).
class _TransitLeg {
  final String fromTitle;
  final String toTitle;
  final int gapMinutes;
  final List<_TransitModeResult> modes;

  const _TransitLeg({
    required this.fromTitle, required this.toTitle,
    required this.gapMinutes, required this.modes,
  });
}

/// Data holder for a single travel-mode estimate used in the transit dialog.
class _TransitModeResult {
  final IconData icon;
  final String label;
  final int minutes;
  final String detail;
  final bool exceeds;

  const _TransitModeResult({
    required this.icon, required this.label,
    required this.minutes, required this.detail, required this.exceeds,
  });
}
