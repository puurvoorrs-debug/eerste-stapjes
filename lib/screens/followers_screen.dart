import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../models/user_model.dart';
import '../providers/profile_provider.dart';

class FollowersScreen extends StatelessWidget {
  final Profile profile;

  const FollowersScreen({super.key, required this.profile});

  Future<List<UserModel>> _fetchFollowerDetails(List<String> followerIds) async {
    if (followerIds.isEmpty) return [];
    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: followerIds)
        .get();
    return userDocs.docs.map((doc) => UserModel.fromDocument(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Volgers van ${profile.name}'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('profiles')
            .doc(profile.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Kon profieldata niet laden.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final followerIds = List<String>.from(data['followers'] ?? []);
          final followRequests =
              Map<String, dynamic>.from(data['followRequests'] ?? {});
          final pendingRequests = followRequests.entries
              .where((e) => (e.value as Map)['status'] == 'pending')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // --- OPENSTAANDE VERZOEKEN ---
              if (pendingRequests.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                  child: Text(
                    'Openstaande volgverzoeken (${pendingRequests.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ...pendingRequests.map((entry) {
                  final userId = entry.key;
                  final reqData = entry.value as Map<String, dynamic>;
                  final name = reqData['name'] ?? 'Onbekend';
                  final photoUrl = reqData['photoUrl'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl.isEmpty
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(name),
                      subtitle: const Text('Wil dit profiel volgen'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green, size: 28),
                            tooltip: 'Accepteren',
                            onPressed: () =>
                                profileProvider.respondToFollowRequest(
                                    profile.id!, userId, 'approved'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.red, size: 28),
                            tooltip: 'Weigeren',
                            onPressed: () =>
                                profileProvider.respondToFollowRequest(
                                    profile.id!, userId, 'rejected'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 24, thickness: 1),
              ],

              // --- BEVESTIGDE VOLGERS ---
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Text(
                  'Volgers (${followerIds.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              if (followerIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text(
                        'Dit profiel heeft nog geen bevestigde volgers.'),
                  ),
                )
              else
                FutureBuilder<List<UserModel>>(
                  future: _fetchFollowerDetails(followerIds),
                  builder: (context, followerSnapshot) {
                    if (followerSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!followerSnapshot.hasData ||
                        followerSnapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('Geen volgersinformatie gevonden.'));
                    }
                    return Column(
                      children: followerSnapshot.data!
                          .map((follower) => ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: follower.photoUrl.isNotEmpty
                                      ? NetworkImage(follower.photoUrl)
                                      : null,
                                  child: follower.photoUrl.isEmpty
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(follower.displayName),
                              ))
                          .toList(),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
