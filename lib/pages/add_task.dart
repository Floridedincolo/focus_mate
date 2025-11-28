import 'package:flutter/material.dart';
import 'package:focus_mate/services/firestore_service.dart';
import 'package:focus_mate/widgets/datepicker.dart';
import 'package:focus_mate/widgets/choose_repeating.dart';
import 'package:focus_mate/widgets/time_picker.dart';
import 'package:focus_mate/widgets/reminder_picker.dart';
import 'package:focus_mate/models/reminder.dart';
import 'package:focus_mate/models/repeatTypes.dart';

import '../models/task.dart';

class AddTaskMenu extends StatefulWidget {
  const AddTaskMenu({super.key});

  @override
  State<AddTaskMenu> createState() => _AddTaskMenuState();
}

class _AddTaskMenuState extends State<AddTaskMenu> {
  bool oneTime = true;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  DateTime? startDate;
  String taskTitle = '';
  List<Reminder> _reminders = [];
  FirestoreService firestoreService = FirestoreService();
  // repeat info
  RepeatType? repeatType=RepeatType.daily;
  Map<String, bool> repeatDays = {};

  Future<void> submitTask() async {
    if (taskTitle.isEmpty) {
      _showError("Task title is required");
      return;
    }
    if (startDate == null) {
      _showError("Start date is required");
      return;
    }
    if (!oneTime) {
      if (repeatType == null) {
        _showError("Repeat type is required");
        return;
      }
      if (repeatType == RepeatType.custom &&
          !repeatDays.containsValue(true)) {
        _showError("Select at least one day for custom repeat");
        return;
      }
      if (startTime == null || endTime == null) {
        _showError("Start and End time are required");
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Task created successfully!"),
        backgroundColor: Colors.green,
      ),
    );

    final task = Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // unique id
      title: taskTitle,
      oneTime: oneTime,
      startDate: startDate!,
      startTime: startTime,
      endTime: endTime,
      reminders: _reminders,
      repeatType: oneTime ? null : repeatType,
      days: oneTime ? {} : repeatDays,
      archived: false,
    );

    await firestoreService.saveTask(task);
    Navigator.pop(context);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _addReminder() async {
    final reminder = await showModalBottomSheet<Reminder>(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      isScrollControlled: true,
      builder: (_) => const ReminderPickerDialog(),
    );
    if (reminder != null) {
      setState(() => _reminders.add(reminder));
    }
  }

  void _deleteReminder(int index) {
    setState(() => _reminders.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        leadingWidth: 50,
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_sharp,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ),
        title: const Text(
          'New Task',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25.0,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF1A1A1A),
                ),
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          oneTime = true;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: oneTime ? Colors.blueAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "One-time task",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          oneTime = false;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: oneTime ? Colors.transparent : Colors.blueAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Recurring task",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                'Task Title',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.0,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                onChanged: (value) => taskTitle = value,
                style: const TextStyle(
                  color: Colors.white70,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter task title',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              const Text(
                'Start Date',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.0,
                ),
              ),
              const SizedBox(height: 5),
              DatePickerField(onDateSelected: (DateTime date) {
                startDate = date;
              }),
              const SizedBox(height: 10),
              if (!oneTime)
                const Text(
                  'Repeat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25.0,
                  ),
                ),
              if (!oneTime)
                const SizedBox(height: 5),
              if (!oneTime)
                ChooseRepeating(
                  repeatType: repeatType ?? RepeatType.daily,
                  d: repeatDays,
                  onRepeatChanged: (RepeatType? type, Map<String, bool> days) {
                    setState(() {
                      repeatType = type;
                      repeatDays = days;
                    });
                  },
                ),
              const SizedBox(height: 10),

              const Text(
                'Time Interval',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.0,
                ),
              ),
              if (!oneTime) const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: TimePicker(
                      label: "Start Time",
                      onTimeSelected: (TimeOfDay time) {
                        startTime = time;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TimePicker(
                      label: "End Time",
                      onTimeSelected: (TimeOfDay time) {
                        endTime = time;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              const Text(
                'Reminder',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25.0,
                ),
              ),
              const SizedBox(height: 5),

              ..._reminders.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final days = r.days.entries
                    .where((d) => d.value)
                    .map((d) => d.key)
                    .toList();

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.time.format(context),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18)),
                            Text("Notify: ${days.join(", ")}",
                                style: const TextStyle(color: Colors.white54)),
                            if (r.message.isNotEmpty)
                              Text(r.message,
                                  style:
                                  const TextStyle(color: Colors.white70)),
                          ]),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteReminder(i),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _addReminder,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_alert, color: Colors.white70),
                      SizedBox(width: 10),
                      Text("Add Reminder",
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GestureDetector(
        onTap: submitTask,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(10),
          child: const Text(
            'Create Task',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
