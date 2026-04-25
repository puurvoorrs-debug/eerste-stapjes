import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String commentText;
  final Timestamp timestamp;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.commentText,
    required this.timestamp,
  });

  // Converteer een CommentModel object naar een Map voor Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'commentText': commentText,
      'timestamp': timestamp,
    };
  }

  // Creëer een CommentModel object vanuit een Firestore DocumentSnapshot
  factory CommentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anoniem',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      commentText: data['commentText'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}
