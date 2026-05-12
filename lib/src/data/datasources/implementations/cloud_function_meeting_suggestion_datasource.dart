import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/meeting_location.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/errors/domain_errors.dart';
import '../../dtos/gemini_raw_proposal.dart';
import '../meeting_suggestion_data_source.dart';

/// Cloud Functions–backed implementation of [MeetingSuggestionDataSource].
///
/// Routes the Gemini call through the `suggestMeetings` Cloud Function so
/// that the prompt, model configuration, structured output schema, and
/// Vertex AI credentials all live server-side.
class CloudFunctionMeetingSuggestionDataSource
    implements MeetingSuggestionDataSource {
  static const _kTimeoutDuration = Duration(seconds: 60);

  final FirebaseFunctions _functions;

  CloudFunctionMeetingSuggestionDataSource(this._functions);

  @override
  Future<List<GeminiRawProposal>> suggestMeetings({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    int maxProposals = 3,
    List<(MeetingLocation? home, MeetingLocation? work)>? memberLocations,
  }) async {
    final payload = _buildPayload(
      memberSchedules: memberSchedules,
      meetingDurationMinutes: meetingDurationMinutes,
      targetDate: targetDate,
      maxProposals: maxProposals,
      memberLocations: memberLocations,
    );

    final callable = _functions.httpsCallable(
      'suggestMeetings',
      options: HttpsCallableOptions(timeout: _kTimeoutDuration),
    );

    final HttpsCallableResult<dynamic> result;
    try {
      result = await callable.call<dynamic>(payload);
    } on FirebaseFunctionsException catch (e) {
      throw AiSuggestionException(
        e.message ?? 'Failed to get meeting suggestions (${e.code}).',
        e,
      );
    } catch (e) {
      throw AiSuggestionException(
        'Failed to call suggestMeetings: $e',
        e is Exception ? e : null,
      );
    }

    final data = result.data;
    if (data is! Map) {
      throw AiSuggestionException(
        'suggestMeetings returned a non-object payload.',
      );
    }

    final proposalsRaw = data['proposals'];
    if (proposalsRaw is! List) {
      throw AiSuggestionException(
        'suggestMeetings response is missing the "proposals" array.',
      );
    }

    final dateOnly = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
    );

    return proposalsRaw
        .whereType<Map>()
        .map((p) => _parseProposal(p, dateOnly))
        .toList();
  }

  // ── Payload building ────────────────────────────────────────────────────

  Map<String, dynamic> _buildPayload({
    required List<List<Task>> memberSchedules,
    required int meetingDurationMinutes,
    required DateTime targetDate,
    required int maxProposals,
    List<(MeetingLocation? home, MeetingLocation? work)>? memberLocations,
  }) {
    final dateStr =
        '${targetDate.year}-'
        '${targetDate.month.toString().padLeft(2, '0')}-'
        '${targetDate.day.toString().padLeft(2, '0')}';

    final members = <Map<String, dynamic>>[];
    for (var i = 0; i < memberSchedules.length; i++) {
      final tasks = memberSchedules[i]
          .where((t) => t.startTime != null && t.endTime != null)
          .map(_serializeTask)
          .toList();

      final m = <String, dynamic>{'tasks': tasks};
      if (memberLocations != null && i < memberLocations.length) {
        final (home, work) = memberLocations[i];
        if (home != null && home.hasCoordinates) {
          m['homeLatitude'] = home.latitude;
          m['homeLongitude'] = home.longitude;
        }
        if (work != null && work.hasCoordinates) {
          m['workLatitude'] = work.latitude;
          m['workLongitude'] = work.longitude;
        }
      }
      members.add(m);
    }

    return {
      'members': members,
      'meetingDurationMinutes': meetingDurationMinutes,
      'targetDate': dateStr,
      'maxProposals': maxProposals,
    };
  }

  Map<String, dynamic> _serializeTask(Task t) {
    final entry = <String, dynamic>{
      'startTime': _fmtTime(t.startTime!),
      'endTime': _fmtTime(t.endTime!),
      'title': t.title,
    };
    if (t.locationLatitude != null && t.locationLongitude != null) {
      entry['locationLatitude'] = t.locationLatitude;
      entry['locationLongitude'] = t.locationLongitude;
    }
    return entry;
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  // ── Response parsing ────────────────────────────────────────────────────

  GeminiRawProposal _parseProposal(Map raw, DateTime date) {
    final start = _parseTimeStr(
      raw['startTime'] as String? ?? '12:00',
      date,
    );
    final end = _parseTimeStr(
      raw['endTime'] as String? ?? '13:00',
      date,
    );
    final lat = (raw['targetLatitude'] as num?)?.toDouble() ?? 47.1560;
    final lng = (raw['targetLongitude'] as num?)?.toDouble() ?? 27.5885;
    final keyword = raw['placeKeyword'] as String? ?? 'cafe';
    final rationale = raw['rationale'] as String?;

    return GeminiRawProposal(
      startTime: start,
      endTime: end,
      targetLatitude: lat,
      targetLongitude: lng,
      placeKeyword: keyword,
      rationale: rationale,
    );
  }

  DateTime _parseTimeStr(String hhmm, DateTime date) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 12;
    final minute =
        parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return date.copyWith(
      hour: hour,
      minute: minute,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
  }
}
