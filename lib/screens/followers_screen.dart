import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/profile.dart';
import '../models/user_model.dart';

class FollowersScreen extends StatelessWidget {
  final Profile profile;

  const FollowersScreen({super.key, required this.profile});

  Future<List<UserModel>> _fetchFollowerDetails() async {
    if (profile.followers.isEmpty) {
      return [];
    }

    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: profile.followers)
        .get();

    return userDocs.docs.map((doc) => UserModel.fromDocument(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Volgers van ${profile.name}'),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _fetchFollowerDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Kon volgers niet laden.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Dit profiel heeft nog geen volgers.'));
          }

          final followers = snapshot.data!;

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: follower.photoUrl.isNotEmpty
                      ? NetworkImage(follower.photoUrl)
                      : null,
                  child: follower.photoUrl.isEmpty
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(follower.displayName),
              );
            },
          );
        },
      ),
    );
  }
}
