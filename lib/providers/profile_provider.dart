import 'dart:async';
import 'dart:io';
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

    _profileSubscription = _firestore
        .collection('users').doc(user.uid).collection('profiles')
        .snapshots()
        .listen((snapshot) {
      _profiles = snapshot.docs.map((doc) => Profile.fromMap(doc.data(), doc.id)).toList();
      notifyListeners();
    });
  }

  Future<String> _uploadImage(File image, String path) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(image);
    final snapshot = await uploadTask; // FIX: Await the task directly
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> addProfile(Profile profile) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? imageUrl;
    if (profile.profileImage != null) {
      imageUrl = await _uploadImage(profile.profileImage!, 'users/${user.uid}/profiles/${profile.name}/profile_image.jpg');
    }

    final newProfile = profile.copyWith(profileImageUrl: imageUrl);
    await _firestore.collection('users').doc(user.uid).collection('profiles').add(newProfile.toMap());
  }

  Future<void> updateProfile(String profileId, Profile newProfileData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    String? imageUrl = newProfileData.profileImageUrl;
    if (newProfileData.profileImage != null) {
      imageUrl = await _uploadImage(newProfileData.profileImage!, 'users/${user.uid}/profiles/${newProfileData.name}/profile_image.jpg');
    }
    
    final updatedProfile = newProfileData.copyWith(profileImageUrl: imageUrl);
    await _firestore.collection('users').doc(user.uid).collection('profiles').doc(profileId).update(updatedProfile.toMap());
  }

  Future<void> deleteProfile(String profileId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final profileRef = _firestore.collection('users').doc(user.uid).collection('profiles').doc(profileId);

    // Delete all daily entries and their associated photos first
    final dailyEntriesSnapshot = await profileRef.collection('daily_entries').get();
    for (final doc in dailyEntriesSnapshot.docs) {
        final data = doc.data();
        if (data['photoUrl'] != null) {
            try {
                await _storage.refFromURL(data['photoUrl']).delete();
            } catch (e) {
                // Log error if file deletion fails, but continue
                debugPrint("Failed to delete photo from storage: $e");
            }
        }
        await doc.reference.delete();
    }

    // Delete the profile picture
    final profileDoc = await profileRef.get();
    if (profileDoc.exists && profileDoc.data()!['profileImageUrl'] != null) {
        try {
            await _storage.refFromURL(profileDoc.data()!['profileImageUrl']).delete();
        } catch (e) {
            debugPrint("Failed to delete profile image from storage: $e");
        }
    }

    // Finally, delete the profile document itself
    await profileRef.delete();
}

  Future<void> addPhotoToProfile(String profileId, String profileName, DateTime date, File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final dateString = date.toIso8601String().split('T').first;
    final imageUrl = await _uploadImage(imageFile, 'users/${user.uid}/profiles/$profileName/photos/$dateString.jpg');

    final dailyEntry = DailyEntry(photoUrl: imageUrl, isFavorite: false);

    await _firestore
        .collection('users').doc(user.uid).collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString)
        .set(dailyEntry.toMap());
  }

  Future<void> toggleFavorite(String profileId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final docRef = _firestore
        .collection('users').doc(user.uid).collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentFavorite = snapshot.data()!['isFavorite'] ?? false;
        transaction.update(docRef, {'isFavorite': !currentFavorite});
      }
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
