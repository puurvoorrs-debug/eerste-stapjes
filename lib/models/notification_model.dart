import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'like', 'comment', 'reply', 'comment_like', 'new_post', 'follow_request', 'follow_request_sent', 'follow_approved', 'download_request', 'download_approved'
  final String profileId;
  final String? entryId;
  final String? commentId;
  final String? senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final Timestamp timestamp;
  final bool isRead;
  final String? status; // 'pending', 'approved', 'rejected' - used for requests

  NotificationModel({
    required this.id,
    required this.type,
    required this.profileId,
    this.entryId,
    this.commentId,
    this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.timestamp,
    this.isRead = false,
    this.status,
  });

  factory NotificationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      type: data['type'] ?? '',
      profileId: data['profileId'] ?? '',
      entryId: data['entryId'],
      commentId: data['commentId'],
      senderId: data['senderId'],
      senderName: data['senderName'] ?? 'Iemand',
      senderPhotoUrl: data['senderPhotoUrl'],
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      status: data['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'profileId': profileId,
      'entryId': entryId,
      'commentId': commentId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'timestamp': timestamp,
      'isRead': isRead,
      'status': status,
    };
  }
}
