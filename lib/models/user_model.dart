import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String photoUrl;
  final String language;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.language,
  });

  // Converteer een UserModel object naar een Map voor Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'language': language,
    };
  }

  // Creëer een UserModel object vanuit een Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      language: data['language'] ?? 'nl',
    );
  }
}
