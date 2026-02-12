import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';
import '../models/comment_model.dart';
import '../providers/profile_provider.dart';

class PhotoDetailScreen extends StatefulWidget {
  final Profile profile;
  final DateTime date;

  const PhotoDetailScreen({super.key, required this.profile, required this.date});

  @override
  _PhotoDetailScreenState createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  final _commentController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  DocumentReference get _entryRef {
    final dateString = widget.date.toIso8601String().split('T').first;
    return FirebaseFirestore.instance
        .collection('profiles')
        .doc(widget.profile.id)
        .collection('daily_entries')
        .doc(dateString);
  }

  void _postComment() {
    if (_commentController.text.trim().isEmpty || _currentUser == null) {
      return;
    }
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    provider.addComment(widget.profile.id!, widget.date, _commentController.text.trim());
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  // NIEUW: Functie om de hele post te verwijderen
  void _deletePost() async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Verwijderen?'),
        content: const Text('Weet je zeker dat je deze post wilt verwijderen? Alle foto\'s, reacties en likes gaan verloren. Deze actie kan niet ongedaan worden gemaakt.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuleren')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Verwijderen', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<ProfileProvider>(context, listen: false).deleteDailyEntry(widget.profile.id!, widget.date);
        if (mounted) {
            Navigator.of(context).pop(); // Ga terug naar het vorige scherm
        }
      } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fout bij verwijderen van post: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateString = widget.date.toIso8601String().split('T').first;
    final bool isOwner = _currentUser?.uid == widget.profile.ownerId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Moment van ${DateFormat('d MMMM yyyy', 'nl_NL').format(widget.date)}'),
        actions: [
          // NIEUW: Verwijderknop voor eigenaar
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
              tooltip: 'Post verwijderen',
            )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _entryRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
             return const Center(child: Text('Deze post bestaat niet meer.'));
          }
          final entry = DailyEntry.fromMap(snapshot.data!.data() as Map<String, dynamic>);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'photo_$dateString',
                  child: Image.network(entry.photoUrl, width: double.infinity, fit: BoxFit.cover),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_currentUser != null)
                            IconButton(
                              icon: Icon(
                                entry.isFavoritedBy(_currentUser.uid) ? Icons.star : Icons.star_border,
                                color: entry.isFavoritedBy(_currentUser.uid) ? Colors.amber : null,
                              ),
                              onPressed: () => Provider.of<ProfileProvider>(context, listen: false).toggleFavorite(widget.profile.id!, widget.date),
                            ),
                          if (_currentUser != null)
                             IconButton(
                              icon: Icon(
                                entry.isLikedBy(_currentUser.uid) ? Icons.favorite : Icons.favorite_border,
                                color: entry.isLikedBy(_currentUser.uid) ? Colors.red : null,
                              ),
                              onPressed: () => Provider.of<ProfileProvider>(context, listen: false).toggleLike(widget.profile.id!, widget.date),
                            ),
                           const SizedBox(width: 8),
                           Text('${entry.likes.length} ${entry.likes.length == 1 ? 'like' : 'likes'}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (entry.description.isNotEmpty)
                        Text(entry.description, style: Theme.of(context).textTheme.bodyLarge),
                      const Divider(height: 30),
                      Text('Reacties', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 10),
                      _buildCommentsList(),
                      const SizedBox(height: 10),
                      if (_currentUser != null) _buildCommentInputField(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // NIEUW: Popup voor bewerken/verwijderen van reactie
  void _showCommentOptions(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Bewerken'),
              onTap: () {
                Navigator.pop(context);
                _showEditCommentDialog(comment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Verwijderen'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteCommentDialog(comment);
              },
            ),
          ],
        );
      },
    );
  }

  // NIEUW: Dialoog voor bewerken van reactie
  void _showEditCommentDialog(CommentModel comment) {
    final editController = TextEditingController(text: comment.commentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reactie bewerken'),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
            TextButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  Provider.of<ProfileProvider>(context, listen: false)
                      .updateComment(widget.profile.id!, widget.date, comment.id, newText);
                  Navigator.pop(context);
                }
              },
              child: const Text('Opslaan'),
            ),
          ],
        );
      },
    );
  }

  // NIEUW: Dialoog voor bevestigen van verwijderen van reactie
  void _showDeleteCommentDialog(CommentModel comment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reactie Verwijderen?'),
          content: const Text('Weet je zeker dat je deze reactie wilt verwijderen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuleren')),
            TextButton(
              onPressed: () {
                Provider.of<ProfileProvider>(context, listen: false)
                    .deleteComment(widget.profile.id!, widget.date, comment.id);
                Navigator.pop(context);
              },
              child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }


  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _entryRef.collection('comments').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final comments = snapshot.data!.docs.map((doc) => CommentModel.fromDocument(doc)).toList();

        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text('Wees de eerste die reageert!')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final bool isCommentOwner = _currentUser?.uid == comment.userId;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: comment.userPhotoUrl.isNotEmpty ? NetworkImage(comment.userPhotoUrl) : null,
                child: comment.userPhotoUrl.isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(comment.userName),
              subtitle: Text(comment.commentText),
              trailing: isCommentOwner
                  ? IconButton(
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => _showCommentOptions(comment),
                    )
                  : Text(
                      DateFormat('dd-MM-yy').format(comment.timestamp.toDate()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildCommentInputField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: const InputDecoration(
              hintText: 'Schrijf een reactie...',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: _postComment,
        ),
      ],
    );
  }
}
