import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String displayName;
  final String photoUrl;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
  });

  // Converteer een UserModel object naar een Map voor Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }

  // Creëer een UserModel object vanuit een Firestore DocumentSnapshot
  factory UserModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
    );
  }
}
