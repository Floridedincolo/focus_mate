import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';

import '../../dtos/gemini_raw_proposal.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/errors/domain_errors.dart';
import '../meeting_suggestion_data_source.dart';

/// Gemini (Vertex AI) implementation of [MeetingSuggestionDataSource].
///
/// Uses the Firebase AI SDK to send a prompt containing all members' schedules
/// and returns parsed [GeminiRawProposal]s with GPS midpoint + place keyword.
///
/// The repository layer resolves the actual place name via [LocationSearchService].
class GeminiMeetingSuggestionDataSource implements MeetingSuggestionDataSource {
  static const _kTimeoutDuration = Duration(seconds: 45);

  late final GenerativeModel _model;

  GeminiMeetingSuggestionDataSource() {
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.0-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.3,
      ),
    );
  }

  @override
  Future<List<GeminiRawProposal>> suggestMeetings({
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
    buffer.writeln('You are a meeting scheduling assistant.');
    buffer.writeln();
    buffer.writeln(
      'Analyse the following schedules for ${memberSchedules.length} people.',
    );
    buffer.writeln('Date: $weekday, $dateStr');
    buffer.writeln('Requested meeting duration: $meetingDurationMinutes minutes');
    buffer.writeln('City context: Iași, Romania (latitude ≈ 47.16, longitude ≈ 27.58)');
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
    buffer.writeln('Instructions:');
    buffer.writeln(
      '1. Find $maxProposals optimal time slots of '
      '$meetingDurationMinutes minutes where ALL members are free.',
    );
    buffer.writeln(
      '2. For each slot, compute a logical GPS midpoint (targetLatitude, '
      'targetLongitude) within the city where the group could meet. '
      'Use coordinates in the Iași area.',
    );
    buffer.writeln(
      '3. Based on the time of day and context, choose a place category '
      'keyword: one of "cafe", "restaurant", "park", "library", "bar", "coworking".',
    );
    buffer.writeln(
      '4. DO NOT invent specific place names — only return the keyword.',
    );
    buffer.writeln(
      '5. Respond EXCLUSIVELY in JSON matching this schema:',
    );
    buffer.writeln();
    buffer.writeln('''{
  "proposals": [
    {
      "startTime": "HH:mm",
      "endTime": "HH:mm",
      "targetLatitude": 47.1560,
      "targetLongitude": 27.5885,
      "placeKeyword": "cafe",
      "rationale": "Brief explanation of why this slot and place type"
    }
  ]
}''');

    return buffer.toString();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Response Parsing ────────────────────────────────────────────────────

  List<GeminiRawProposal> _parseResponse(String raw, DateTime targetDate) {
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

    return proposals.map<GeminiRawProposal>((p) {
      final map = p as Map<String, dynamic>;
      final start = _parseTimeStr(map['startTime'] as String? ?? '12:00', date);
      final end = _parseTimeStr(map['endTime'] as String? ?? '13:00', date);
      final lat = (map['targetLatitude'] as num?)?.toDouble() ?? 47.1560;
      final lng = (map['targetLongitude'] as num?)?.toDouble() ?? 27.5885;
      final keyword = map['placeKeyword'] as String? ?? 'cafe';
      final rationale = map['rationale'] as String?;

      return GeminiRawProposal(
        startTime: start,
        endTime: end,
        targetLatitude: lat,
        targetLongitude: lng,
        placeKeyword: keyword,
        rationale: rationale,
      );
    }).toList();
  }

  DateTime _parseTimeStr(String hhmm, DateTime date) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return date.copyWith(
        hour: hour, minute: minute, second: 0, millisecond: 0, microsecond: 0);
  }
}

