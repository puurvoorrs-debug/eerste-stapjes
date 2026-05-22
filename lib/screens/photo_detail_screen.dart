import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';
import '../models/comment_model.dart';
import '../providers/profile_provider.dart';
import '../providers/locale_provider.dart';

// HOOFDWIDGET: BEHEERT DE PAGEVIEW
class PhotoDetailScreen extends StatefulWidget {
  final Profile profile;
  final Map<DateTime, DailyEntry> entries;
  final DateTime initialDate;

  const PhotoDetailScreen({
    super.key,
    required this.profile,
    required this.entries,
    required this.initialDate,
  });

  @override
  _PhotoDetailScreenState createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PageController _pageController;
  late List<DateTime> _sortedDates;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // CORRECTIE: Sorteer de datums oplopend (oud naar nieuw)
    _sortedDates = widget.entries.keys.toList()..sort((a, b) => a.compareTo(b));
    
    // Vind de index van de geselecteerde datum
    _currentIndex = _sortedDates.indexWhere((d) => isSameDay(d, widget.initialDate));
    if (_currentIndex == -1) _currentIndex = 0;

    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _sortedDates.length,
      itemBuilder: (context, index) {
        final date = _sortedDates[index];
        final entry = widget.entries[date];

        if (entry == null) {
          return Scaffold(
            body: Center(child: Text(context.tr('Fout: Kon entry niet laden.', 'Error: Could not load entry.'))),
          );
        }

        return _PhotoPage(
          key: ValueKey(date),
          profile: widget.profile,
          date: date,
        );
      },
    );
  }

   bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// PAGINA WIDGET: TOONT DE CONTENT VAN ÉÉN DAG (FOTO, REACTIES, ETC.)
class _PhotoPage extends StatefulWidget {
  final Profile profile;
  final DateTime date;

  const _PhotoPage({super.key, required this.profile, required this.date});

  @override
  __PhotoPageState createState() => __PhotoPageState();
}

class __PhotoPageState extends State<_PhotoPage> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  String? _replyingToCommentId;
  String? _replyingToUserName;

  DocumentReference get _entryRef {
    final dateString = widget.date.toIso8601String().split('T').first;
    return FirebaseFirestore.instance
        .collection('profiles')
        .doc(widget.profile.id)
        .collection('daily_entries')
        .doc(dateString);
  }

  late final Stream<DocumentSnapshot> _entryStream;

  @override
  void initState() {
    super.initState();
    _entryStream = _entryRef.snapshots();
  }

  bool _isDownloading = false;

  Future<void> _downloadImage(String url) async {
    setState(() => _isDownloading = true);
    try {
      // Controleer of we toegang hebben tot de galerij
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Geen toegang tot de galerij. Geef de app toestemming in de instellingen.', 'No access to gallery. Please grant permission in settings.'))),
          );
        }
        return;
      }

      final appDocDir = await getTemporaryDirectory();
      final savePath = '${appDocDir.path}/temp_image.jpg';
      await Dio().download(url, savePath);
      await Gal.putImage(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Foto is opgeslagen in je galerij!', 'Photo saved to gallery!'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Fout bij downloaden', 'Error downloading')}: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Widget _buildOwnerDownloadRequests(DailyEntry entry) {
    if (entry.downloadRequests.isEmpty) return const SizedBox.shrink();

    final pendingRequests = entry.downloadRequests.entries.where((e) => e.value['status'] == 'pending').toList();
    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Download Aanvragen', 'Download Requests'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...pendingRequests.map((req) {
            final userId = req.key;
            final name = req.value['name'] ?? 'Iemand';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('$name wil deze foto downloaden', '$name wants to download this photo')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => Provider.of<ProfileProvider>(context, listen: false).respondToDownloadRequest(widget.profile.id!, widget.date, userId, 'approved'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => Provider.of<ProfileProvider>(context, listen: false).respondToDownloadRequest(widget.profile.id!, widget.date, userId, 'rejected'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFollowerDownloadSection(DailyEntry entry) {
    if (_currentUser == null) return const SizedBox.shrink();
    
    final request = entry.downloadRequests[_currentUser!.uid];
    final status = request != null ? request['status'] : null;

    if (status == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.file_download),
          label: Text(context.tr('Download Aanvragen', 'Request Download')),
          onPressed: () => Provider.of<ProfileProvider>(context, listen: false).requestPhotoDownload(widget.profile.id!, widget.date),
        ),
      );
    } else if (status == 'pending') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.hourglass_empty),
          label: Text(context.tr('Aanvraag in behandeling', 'Request pending')),
          onPressed: null,
        ),
      );
    } else if (status == 'rejected') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.cancel, color: Colors.red),
          label: Text(context.tr('Aanvraag afgewezen', 'Request rejected'), style: const TextStyle(color: Colors.red)),
          onPressed: null,
        ),
      );
    } else if (status == 'approved') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ElevatedButton.icon(
          icon: _isDownloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.file_download),
          label: Text(_isDownloading ? context.tr('Downloaden...', 'Downloading...') : context.tr('Download Foto', 'Download Photo')),
          onPressed: _isDownloading ? null : () => _downloadImage(entry.photoUrl),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _postComment() {
    if (_commentController.text.trim().isEmpty || _currentUser == null) return;
    final provider = Provider.of<ProfileProvider>(context, listen: false);
    provider.addComment(
      widget.profile.id!, 
      widget.date, 
      _commentController.text.trim(),
      parentId: _replyingToCommentId,
    );
    _commentController.clear();
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
    FocusScope.of(context).unfocus();
  }

  void _startReply(CommentModel comment) {
    setState(() {
      // If it's already a reply, reply to the same parent to keep it 1 level deep
      _replyingToCommentId = comment.parentId ?? comment.id;
      _replyingToUserName = comment.userName;
    });
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  void _deletePost() async {
    final bool? confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Post Verwijderen?', 'Delete Post?')),
        content: Text(context.tr('Weet je zeker dat je deze post wilt verwijderen? Deze actie kan niet ongedaan worden gemaakt.', 'Are you sure you want to delete this post? This action cannot be undone.')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.tr('Annuleren', 'Cancel'))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.tr('Verwijderen', 'Delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<ProfileProvider>(context, listen: false).deleteDailyEntry(widget.profile.id!, widget.date);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.tr('Fout bij verwijderen', 'Error deleting')}: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateString = widget.date.toIso8601String().split('T').first;
    final isOwner = _currentUser?.uid == widget.profile.ownerId;

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('Moment van', 'Moment of')} ${DateFormat('d MMMM yyyy', context.tr('nl_NL', 'en_US')).format(widget.date)}'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deletePost,
              tooltip: context.tr('Post verwijderen', 'Delete post'),
            )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _entryStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text(context.tr('Deze post bestaat niet meer of wordt geladen.', 'This post no longer exists or is being loaded.')));
          }
          final entry = DailyEntry.fromMap(snapshot.data!.data() as Map<String, dynamic>);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                            
                            const SizedBox(height: 12),
                            if (isOwner) _buildOwnerDownloadRequests(entry),
                            if (!isOwner) _buildFollowerDownloadSection(entry),

                            const Divider(height: 30),
                            Text(context.tr('Reacties', 'Comments'), style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 10),
                            _buildCommentsList(),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentUser != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0 + MediaQuery.of(context).padding.bottom,
                    top: 8.0,
                  ),
                  child: _buildCommentInputField(),
                ),
            ],
          );
        },
      ),
    );
  }
  
  void _showCommentOptions(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.tr('Bewerken', 'Edit')),
              onTap: () {
                Navigator.pop(context);
                _showEditCommentDialog(comment);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(context.tr('Verwijderen', 'Delete')),
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

  void _showEditCommentDialog(CommentModel comment) {
    final editController = TextEditingController(text: comment.commentText);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Reactie bewerken', 'Edit comment')),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: null,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuleren', 'Cancel'))),
            TextButton(
              onPressed: () {
                final newText = editController.text.trim();
                if (newText.isNotEmpty) {
                  Provider.of<ProfileProvider>(context, listen: false)
                      .updateComment(widget.profile.id!, widget.date, comment.id, newText);
                  Navigator.pop(context);
                }
              },
              child: Text(context.tr('Opslaan', 'Save')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCommentDialog(CommentModel comment) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Reactie Verwijderen?', 'Delete Comment?')),
          content: Text(context.tr('Weet je zeker dat je deze reactie wilt verwijderen?', 'Are you sure you want to delete this comment?')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('Annuleren', 'Cancel'))),
            TextButton(
              onPressed: () {
                Provider.of<ProfileProvider>(context, listen: false)
                    .deleteComment(widget.profile.id!, widget.date, comment.id);
                Navigator.pop(context);
              },
              child: Text(context.tr('Verwijderen', 'Delete'), style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _entryRef.collection('comments').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allComments = snapshot.data!.docs.map((doc) => CommentModel.fromDocument(doc)).toList();

        if (allComments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(child: Text(context.tr('Wees de eerste die reageert!', 'Be the first to comment!'))),
          );
        }

        // Group comments by parentId
        final rootComments = allComments.where((c) => c.parentId == null).toList();
        final childComments = allComments.where((c) => c.parentId != null).toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rootComments.length,
          itemBuilder: (context, index) {
            final rootComment = rootComments[index];
            final replies = childComments.where((c) => c.parentId == rootComment.id).toList();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentTile(rootComment, isReply: false),
                if (replies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 40.0),
                    child: Column(
                      children: replies.map((reply) => _buildCommentTile(reply, isReply: true)).toList(),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCommentTile(CommentModel comment, {required bool isReply}) {
    final bool isCommentOwner = _currentUser?.uid == comment.userId;
    final bool isLiked = _currentUser != null && comment.likes.contains(_currentUser!.uid);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 14 : 18,
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: comment.userPhotoUrl.isNotEmpty ? NetworkImage(comment.userPhotoUrl) : null,
            child: comment.userPhotoUrl.isEmpty ? Icon(Icons.person, size: isReply ? 16 : 20, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd-MM-yy').format(comment.timestamp.toDate()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.commentText),
                const SizedBox(height: 4),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _startReply(comment),
                      child: Text(context.tr('Reageer', 'Reply'), style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    if (isCommentOwner) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => _showCommentOptions(comment),
                        child: Text(context.tr('Opties', 'Options'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: isLiked ? Colors.red : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (_currentUser != null) {
                    Provider.of<ProfileProvider>(context, listen: false)
                        .toggleCommentLike(widget.profile.id!, widget.date, comment.id);
                  }
                },
              ),
              if (comment.likes.isNotEmpty)
                Text('${comment.likes.length}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyingToCommentId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${context.tr('Antwoorden op', 'Replying to')} $_replyingToUserName', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cancelReply,
                  child: Icon(Icons.close, size: 16, color: Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                decoration: InputDecoration(
                  hintText: context.tr('Schrijf een reactie...', 'Write a comment...'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _postComment,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
