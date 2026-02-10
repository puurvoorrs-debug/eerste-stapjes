import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';

class ProfileProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Profile> _profiles = [];
  StreamSubscription? _profileSubscription;

  List<Profile> get profiles => _profiles;

  ProfileProvider() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        fetchProfiles();
      } else {
        _profileSubscription?.cancel();
        _profiles = [];
        notifyListeners();
      }
    });
  }

  void fetchProfiles() {
    final user = _auth.currentUser;
    if (user == null) return;

    _profileSubscription?.cancel();

    _profileSubscription = _firestore
        .collection('profiles')
        .where(Filter.or(
          Filter('ownerId', isEqualTo: user.uid),
          Filter('followers', arrayContains: user.uid),
        ))
        .snapshots()
        .listen((snapshot) {
      _profiles = snapshot.docs.map((doc) => Profile.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    }, onError: (error) {
      debugPrint("Error fetching profiles: $error");
    });
  }

  String _generateShareCode() {
    const length = 6;
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<String> _uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(image);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> addProfile(Profile profile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newProfileRef = _firestore.collection('profiles').doc();
    final profileId = newProfileRef.id;

    String? imageUrl;
    if (profile.profileImage != null) {
      imageUrl = await _uploadImage(profile.profileImage!, 'profiles/$profileId/profile_image.jpg');
    }

    final newProfile = profile.copyWith(
      id: profileId,
      profileImageUrl: imageUrl,
      ownerId: user.uid,
      shareCode: _generateShareCode(),
    );

    await newProfileRef.set(newProfile.toMap());
  }

  Future<void> updateProfile(String profileId, Profile newProfileData) async {
    String? imageUrl = newProfileData.profileImageUrl;
    if (newProfileData.profileImage != null) {
      imageUrl = await _uploadImage(newProfileData.profileImage!, 'profiles/$profileId/profile_image.jpg');
    }
    
    final updatedProfile = newProfileData.copyWith(profileImageUrl: imageUrl);
    await _firestore.collection('profiles').doc(profileId).update(updatedProfile.toMap());
  }

  Future<void> deleteProfile(String profileId) async {
    final profileRef = _firestore.collection('profiles').doc(profileId);

    final dailyEntriesSnapshot = await profileRef.collection('daily_entries').get();
    for (final doc in dailyEntriesSnapshot.docs) {
        final data = doc.data();
        if (data['photoUrl'] != null) {
            try {
                await _storage.refFromURL(data['photoUrl']).delete();
            } catch (e) {
                debugPrint("Failed to delete photo from storage: $e");
            }
        }
        await doc.reference.delete();
    }

    final profileDoc = await profileRef.get();
    if (profileDoc.exists && profileDoc.data()!['profileImageUrl'] != null) {
        try {
            await _storage.refFromURL(profileDoc.data()!['profileImageUrl']).delete();
        } catch (e) {
            debugPrint("Failed to delete profile image from storage: $e");
        }
    }

    await profileRef.delete();
  }

  Future<void> addPhotoToProfile(String profileId, DateTime date, File imageFile) async {
    final dateString = date.toIso8601String().split('T').first;
    final imageUrl = await _uploadImage(imageFile, 'profiles/$profileId/photos/$dateString.jpg');

    // Create a new entry with an empty favoritedBy list
    final dailyEntry = DailyEntry(photoUrl: imageUrl, favoritedBy: []);

    await _firestore
        .collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString)
        .set(dailyEntry.toMap());
  }

  Future<void> toggleFavorite(String profileId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final docRef = _firestore
        .collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final List<String> favoritedBy = List<String>.from(data['favoritedBy'] ?? []);

        if (favoritedBy.contains(user.uid)) {
          // User already favorited, so remove them
          transaction.update(docRef, {'favoritedBy': FieldValue.arrayRemove([user.uid])});
        } else {
          // User has not favorited, so add them
          transaction.update(docRef, {'favoritedBy': FieldValue.arrayUnion([user.uid])});
        }
      }
    });
  }

  Future<bool> followProfile(String shareCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final querySnapshot = await _firestore
        .collection('profiles')
        .where('shareCode', isEqualTo: shareCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return false;
    }

    final profileDoc = querySnapshot.docs.first;
    final profileData = profileDoc.data();

    if (profileData['ownerId'] == user.uid) {
      return false;
    }
    
    await profileDoc.reference.update({
      'followers': FieldValue.arrayUnion([user.uid])
    });

    return true;
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
