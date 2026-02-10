import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';

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

  // Gecorrigeerd: Accepteert nu metadata voor de upload.
  Future<String> _uploadImage(File image, String path, {String? ownerId}) async {
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(customMetadata: {
      if (ownerId != null) 'ownerId': ownerId,
    });

    final uploadTask = ref.putFile(image, metadata);
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
      // Gecorrigeerd: ownerId wordt meegegeven aan de upload.
      imageUrl = await _uploadImage(
        profile.profileImage!,
        'profile_pictures/$profileId/profile_image.jpg',
        ownerId: user.uid,
      );
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
    final user = _auth.currentUser;
    if (user == null) return;

    String? imageUrl = newProfileData.profileImageUrl;
    if (newProfileData.profileImage != null) {
      // Gecorrigeerd: ownerId wordt meegegeven aan de upload.
      imageUrl = await _uploadImage(
        newProfileData.profileImage!,
        'profile_pictures/$profileId/profile_image.jpg',
        ownerId: user.uid, // Belangrijk voor autorisatie
      );
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

  // AANGEPAST: Accepteert nu een beschrijving en metadata voor dagelijkse foto's
  Future<void> addPhotoToProfile(String profileId, DateTime date, File imageFile, {String description = ''}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Haal de lijst met volgers op om in de metadata op te slaan
    final profileDoc = await _firestore.collection('profiles').doc(profileId).get();
    final followers = List<String>.from(profileDoc.data()?['followers'] ?? []);

    final dateString = date.toIso8601String().split('T').first;
    final imageUrl = await _uploadImage(
      imageFile, 
      'daily_pictures/$profileId/$dateString.jpg',
      ownerId: user.uid, // Eigenaar UID toevoegen voor de beveiligingsregel
    );

    final dailyEntry = DailyEntry(
      photoUrl: imageUrl,
      description: description,
      favoritedBy: [],
      likes: [],
    );

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

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final List<String> favoritedBy = List<String>.from(data['favoritedBy'] ?? []);

      if (favoritedBy.contains(user.uid)) {
        transaction.update(docRef, {'favoritedBy': FieldValue.arrayRemove([user.uid])});
      } else {
        transaction.update(docRef, {'favoritedBy': FieldValue.arrayUnion([user.uid])});
      }
    });
  }

  // NIEUW: Like-functionaliteit
  Future<void> toggleLike(String profileId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final docRef = _firestore
        .collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final List<String> likes = List<String>.from(data['likes'] ?? []);

      if (likes.contains(user.uid)) {
        transaction.update(docRef, {'likes': FieldValue.arrayRemove([user.uid])});
      } else {
        transaction.update(docRef, {'likes': FieldValue.arrayUnion([user.uid])});
      }
    });
  }

  // NIEUW: Reactie toevoegen
  Future<void> addComment(String profileId, DateTime date, String commentText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Haal de profielgegevens van de huidige gebruiker op
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return; // Gebruiker moet een profiel hebben
    final userProfile = UserModel.fromDocument(userDoc);

    final dateString = date.toIso8601String().split('T').first;
    final commentRef = _firestore
        .collection('profiles').doc(profileId)
        .collection('daily_entries').doc(dateString)
        .collection('comments').doc();

    final newComment = CommentModel(
      id: commentRef.id,
      userId: user.uid,
      userName: userProfile.displayName,
      userPhotoUrl: userProfile.photoUrl,
      commentText: commentText,
      timestamp: Timestamp.now(),
    );

    await commentRef.set(newComment.toMap());
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
      return false; // Kan eigen profiel niet volgen
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
