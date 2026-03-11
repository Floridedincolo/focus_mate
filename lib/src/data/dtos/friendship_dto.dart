import 'package:cloud_firestore/cloud_firestore.dart';

/// DTO that mirrors the `friendships/{friendshipId}` Firestore document.
class FriendshipDto {
  final String id;
  final String requesterId;
  final String receiverId;
  final String status; // "pending" | "accepted" | "declined"
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const FriendshipDto({
    required this.id,
    required this.requesterId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FriendshipDto.fromFirestore(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return FriendshipDto(
      id: documentId,
      requesterId: data['requesterId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'receiverId': receiverId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

