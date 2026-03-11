import 'package:cloud_firestore/cloud_firestore.dart';

/// DTO for the `meetingProposals/{proposalId}` Firestore document.
///
/// The `location` sub-map is flattened into this DTO for simplicity.
class MeetingProposalDto {
  final String id;
  final List<String> groupMemberUids;
  final Timestamp startTime;
  final Timestamp endTime;
  final String locationName;
  final double? locationLatitude;
  final double? locationLongitude;
  final String source; // "algorithmic" | "ai"
  final String? aiRationale;
  final Timestamp createdAt;

  const MeetingProposalDto({
    required this.id,
    required this.groupMemberUids,
    required this.startTime,
    required this.endTime,
    required this.locationName,
    this.locationLatitude,
    this.locationLongitude,
    required this.source,
    this.aiRationale,
    required this.createdAt,
  });

  factory MeetingProposalDto.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final location = data['location'] as Map<String, dynamic>? ?? {};
    return MeetingProposalDto(
      id: documentId,
      groupMemberUids: List<String>.from(data['groupMemberUids'] ?? []),
      startTime: data['startTime'] as Timestamp? ?? Timestamp.now(),
      endTime: data['endTime'] as Timestamp? ?? Timestamp.now(),
      locationName: location['name'] as String? ?? 'Location TBD',
      locationLatitude: (location['latitude'] as num?)?.toDouble(),
      locationLongitude: (location['longitude'] as num?)?.toDouble(),
      source: data['source'] as String? ?? 'algorithmic',
      aiRationale: data['aiRationale'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupMemberUids': groupMemberUids,
      'startTime': startTime,
      'endTime': endTime,
      'location': {
        'name': locationName,
        'latitude': locationLatitude,
        'longitude': locationLongitude,
      },
      'source': source,
      if (aiRationale != null) 'aiRationale': aiRationale,
      'createdAt': createdAt,
    };
  }
}

