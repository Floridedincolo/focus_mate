import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/meeting_location.dart';
import '../../domain/entities/meeting_proposal.dart';
import '../dtos/meeting_proposal_dto.dart';

/// Mapper between MeetingProposal domain entities and their DTOs.
class MeetingProposalMapper {
  static MeetingProposal toDomain(MeetingProposalDto dto) {
    return MeetingProposal(
      groupMemberUids: dto.groupMemberUids,
      startTime: dto.startTime.toDate(),
      endTime: dto.endTime.toDate(),
      location: MeetingLocation(
        name: dto.locationName,
        latitude: dto.locationLatitude,
        longitude: dto.locationLongitude,
      ),
      source: _parseSource(dto.source),
      aiRationale: dto.aiRationale,
    );
  }

  static MeetingProposalDto toDto(MeetingProposal entity, {String id = ''}) {
    return MeetingProposalDto(
      id: id,
      groupMemberUids: entity.groupMemberUids,
      startTime: Timestamp.fromDate(entity.startTime),
      endTime: Timestamp.fromDate(entity.endTime),
      locationName: entity.location.name,
      locationLatitude: entity.location.latitude,
      locationLongitude: entity.location.longitude,
      source: entity.source.name,
      aiRationale: entity.aiRationale,
      createdAt: Timestamp.now(),
    );
  }

  static List<MeetingProposal> toDomainList(List<MeetingProposalDto> dtos) {
    return dtos.map(toDomain).toList();
  }

  static ProposalSource _parseSource(String raw) {
    switch (raw) {
      case 'ai':
        return ProposalSource.ai;
      case 'algorithmic':
      default:
        return ProposalSource.algorithmic;
    }
  }
}
