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
import '../models/app_exception.dart';

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
      imageUrl = await _uploadImage(
        newProfileData.profileImage!,
        'profile_pictures/$profileId/profile_image.jpg',
        ownerId: user.uid,
      );
    }
    
    final updatedProfile = newProfileData.copyWith(profileImageUrl: imageUrl);
    await _firestore.collection('profiles').doc(profileId).update(updatedProfile.toMap());
  }

  Future<void> deleteProfile(String profileId) async {
    final profileRef = _firestore.collection('profiles').doc(profileId);

    final dailyEntriesSnapshot = await profileRef.collection('daily_entries').get();
    for (final doc in dailyEntriesSnapshot.docs) {
        await deleteDailyEntry(profileId, DateTime.parse(doc.id));
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

  Future<void> deleteDailyEntry(String profileId, DateTime date) async {
    final dateString = date.toIso8601String().split('T').first;
    final entryRef = _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString);

    final entryDoc = await entryRef.get();
    if (!entryDoc.exists) return;

    final commentsSnapshot = await entryRef.collection('comments').get();
    for (final doc in commentsSnapshot.docs) {
      await doc.reference.delete();
    }

    final data = entryDoc.data();
    if (data != null && data['photoUrl'] != null) {
      try {
        await _storage.refFromURL(data['photoUrl']).delete();
      } catch (e) {
        debugPrint("Failed to delete daily photo from storage: $e");
      }
    }

    await entryRef.delete();
  }

  Future<void> addPhotoToProfile(String profileId, DateTime date, File imageFile, {String description = ''}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final entryRef = _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString);

    if ((await entryRef.get()).exists) {
      await deleteDailyEntry(profileId, date);
    }

    final imageUrl = await _uploadImage(
      imageFile, 
      'daily_pictures/$profileId/$dateString.jpg',
      ownerId: user.uid,
    );

    final dailyEntry = DailyEntry(
      photoUrl: imageUrl,
      description: description,
      favoritedBy: [],
      likes: [],
    );

    await entryRef.set(dailyEntry.toMap());
  }

  Future<void> toggleFavorite(String profileId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final docRef = _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString);

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

  Future<void> toggleLike(String profileId, DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateString = date.toIso8601String().split('T').first;
    final docRef = _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString);

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

  Future<void> addComment(String profileId, DateTime date, String commentText) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;
    final userProfile = UserModel.fromDocument(userDoc);

    final dateString = date.toIso8601String().split('T').first;
    final commentRef = _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString).collection('comments').doc();

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

  Future<void> deleteComment(String profileId, DateTime date, String commentId) async {
    final dateString = date.toIso8601String().split('T').first;
    await _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString).collection('comments').doc(commentId).delete();
  }

  Future<void> updateComment(String profileId, DateTime date, String commentId, String newText) async {
    final dateString = date.toIso8601String().split('T').first;
    await _firestore.collection('profiles').doc(profileId).collection('daily_entries').doc(dateString).collection('comments').doc(commentId).update({
      'commentText': newText,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> followProfile(String shareCode) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) {
      throw IncompleteProfileException('Gebruikersprofiel niet gevonden.');
    }

    final userData = userDoc.data()!;
    final userName = userData['displayName'] as String?;
    final photoUrl = userData['photoUrl'] as String?;

    if (userName == null || userName.isEmpty || photoUrl == null || photoUrl.isEmpty) {
      throw IncompleteProfileException(
          'Update je profiel met een naam en foto om anderen te volgen.');
    }

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
