import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';

class Profile {
  final String? id;
  final String name;
  final DateTime dateOfBirth;
  final String? profileImageUrl;
  final File? profileImage; // Temporary for image picking
  final String ownerId; // UID of the user who owns/manages the profile
  final List<String> followers; // List of UIDs of users following the profile
  final String? shareCode; // Unique code to share the profile

  Profile({
    this.id,
    required this.name,
    required this.dateOfBirth,
    this.profileImageUrl,
    this.profileImage,
    required this.ownerId,
    this.followers = const [],
    this.shareCode,
  });

  Profile copyWith({
    String? id,
    String? name,
    DateTime? dateOfBirth,
    String? profileImageUrl,
    File? profileImage,
    String? ownerId,
    List<String>? followers,
    String? shareCode,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImage: profileImage ?? this.profileImage,
      ownerId: ownerId ?? this.ownerId,
      followers: followers ?? this.followers,
      shareCode: shareCode ?? this.shareCode,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map, String id) {
    return Profile(
      id: id,
      name: map['name'] as String,
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      profileImageUrl: map['profileImageUrl'] as String?,
      ownerId: map['ownerId'] as String,
      followers: List<String>.from(map['followers'] ?? []),
      shareCode: map['shareCode'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'profileImageUrl': profileImageUrl,
      'ownerId': ownerId,
      'followers': followers,
      'shareCode': shareCode,
    };
  }
}
