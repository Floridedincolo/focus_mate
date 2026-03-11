import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/meeting_location.dart';
import '../../../domain/entities/meeting_proposal.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/errors/domain_errors.dart';
import '../meeting_suggestion_data_source.dart';

/// Gemini (Vertex AI) implementation of [MeetingSuggestionDataSource].
///
/// Uses the Firebase AI SDK to send a prompt containing all members' schedules
/// and returns parsed [MeetingProposal]s.
class GeminiMeetingSuggestionDataSource implements MeetingSuggestionDataSource {
  static const _kTimeoutDuration = Duration(seconds: 45);

  late final GenerativeModel _model;

  GeminiMeetingSuggestionDataSource() {
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.4, // slightly creative for location suggestions
      ),
    );
  }

  @override
  Future<List<MeetingProposal>> suggestMeetings({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
  }) async {
    final prompt = _buildPrompt(
      memberSchedules: memberSchedules,
      meetingDurationMinutes: meetingDurationMinutes,
      targetDate: targetDate,
      maxProposals: maxProposals,
    );

    final String rawText;
    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(_kTimeoutDuration);
      rawText = response.text ?? '';
    } catch (e) {
      throw AiSuggestionException(
        'Failed to get a response from Gemini: $e',
        e is Exception ? e : null,
      );
    }

    if (rawText.trim().isEmpty) {
      throw AiSuggestionException('Gemini returned an empty response.');
    }

    return _parseResponse(rawText, targetDate);
  }

  // ── Prompt Building ─────────────────────────────────────────────────────

  String _buildPrompt({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    required int maxProposals,
  }) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final weekday = weekdays[targetDate.weekday - 1];
    final dateStr =
        '${targetDate.year}-'
        '${targetDate.month.toString().padLeft(2, '0')}-'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    buffer.writeln(
      'Analyse the following schedules for ${memberSchedules.length} people.',
    );
    buffer.writeln('Date: $weekday, $dateStr');
    buffer.writeln('Requested meeting duration: $meetingDurationMinutes minutes');
    buffer.writeln();
    buffer.writeln('Schedules:');

    for (var i = 0; i < memberSchedules.length; i++) {
      final tasks = memberSchedules[i];
      final formatted = tasks
          .where((t) => t.startTime != null && t.endTime != null)
          .map((t) =>
              '${_fmtTime(t.startTime!)}-${_fmtTime(t.endTime!)} ${t.title}')
          .join(', ');
      buffer.writeln(
        '  Person ${i + 1}: [${formatted.isEmpty ? "no activities" : formatted}]',
      );
    }

    buffer.writeln();
    buffer.writeln('Task:');
    buffer.writeln(
      '1. Find $maxProposals optimal time slots for a meeting of '
      '$meetingDurationMinutes minutes where ALL members are free.',
    );
    buffer.writeln(
      '2. Based on context (time of day, preceding activities), '
      'suggest a location type (e.g. Coffee Shop, Restaurant, Park, Library).',
    );
    buffer.writeln(
      '3. Respond EXCLUSIVELY in JSON following the schema below.',
    );
    buffer.writeln();
    buffer.writeln('JSON schema:');
    buffer.writeln('''{
  "proposals": [
    {
      "startTime": "HH:mm",
      "endTime": "HH:mm",
      "locationName": "Coffee Shop",
      "rationale": "Brief explanation"
    }
  ]
}''');

    return buffer.toString();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Response Parsing ────────────────────────────────────────────────────

  List<MeetingProposal> _parseResponse(String raw, DateTime targetDate) {
    // Strip markdown fences if the model wraps the JSON
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```\w*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw AiSuggestionException(
        'Failed to parse Gemini JSON response: $e\n'
        'Raw (first 500 chars): ${raw.substring(0, raw.length.clamp(0, 500))}',
      );
    }

    final proposals = json['proposals'] as List<dynamic>? ?? [];
    final date = DateTime(targetDate.year, targetDate.month, targetDate.day);

    return proposals.map<MeetingProposal>((p) {
      final map = p as Map<String, dynamic>;
      final start = _parseTimeStr(map['startTime'] as String? ?? '12:00', date);
      final end = _parseTimeStr(map['endTime'] as String? ?? '13:00', date);
      final locName = map['locationName'] as String? ?? 'Suggested location';
      final rationale = map['rationale'] as String?;

      return MeetingProposal(
        startTime: start,
        endTime: end,
        location: MeetingLocation(name: locName),
        source: ProposalSource.ai,
        aiRationale: rationale,
      );
    }).toList();
  }

  DateTime _parseTimeStr(String hhmm, DateTime date) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return date.copyWith(hour: hour, minute: minute, second: 0, millisecond: 0, microsecond: 0);
  }
}

