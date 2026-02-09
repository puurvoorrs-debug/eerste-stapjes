import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profile {
  final String? id;
  final String name;
  final DateTime dateOfBirth;
  final String? profileImageUrl;
  final File? profileImage; // Temporary for image picking

  Profile({
    this.id,
    required this.name,
    required this.dateOfBirth,
    this.profileImageUrl,
    this.profileImage,
  });

  Profile copyWith({
    String? id,
    String? name,
    DateTime? dateOfBirth,
    String? profileImageUrl,
    File? profileImage,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImage: profileImage ?? this.profileImage,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map, String id) {
    return Profile(
      id: id,
      name: map['name'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'profileImageUrl': profileImageUrl,
    };
  }
}
