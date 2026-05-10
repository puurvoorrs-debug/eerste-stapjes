import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';
import 'photo_detail_screen.dart';

class DailyEntryDetailScreen extends StatefulWidget {
  final String entryId;
  final String profileId;

  const DailyEntryDetailScreen({
    super.key,
    required this.entryId,
    required this.profileId,
  });

  @override
  State<DailyEntryDetailScreen> createState() => _DailyEntryDetailScreenState();
}

class _DailyEntryDetailScreenState extends State<DailyEntryDetailScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isPermissionError = false;

  @override
  void initState() {
    super.initState();
    _loadDataAndNavigate();
  }

  Future<void> _loadDataAndNavigate() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1. Haal het profiel op
      final profileDoc = await firestore.collection('profiles').doc(widget.profileId).get();
      if (!profileDoc.exists) {
        throw Exception('Profiel niet gevonden.');
      }
      final profile = Profile.fromMap(profileDoc.data()!, profileDoc.id);
      final profileData = profileDoc.data()!;
      final ownerId = profileData['ownerId'] as String?;
      final followers = List<String>.from(profileData['followers'] ?? []);

      // 2. Controleer of de gebruiker toegang heeft (eigenaar of volger)
      final hasAccess = currentUser != null &&
          (ownerId == currentUser.uid || followers.contains(currentUser.uid));

      if (!hasAccess) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPermissionError = true;
            _errorMessage =
                'Je hebt geen toegang meer tot dit profiel. Mogelijk is je volgverzoek nog niet goedgekeurd of ben je ontvolgt.';
          });
        }
        return;
      }

      // 3. Haal alle entries op voor het profiel (voor swipe-functionaliteit)
      final entriesSnapshot = await firestore
          .collection('profiles')
          .doc(widget.profileId)
          .collection('daily_entries')
          .get();

      final entries = <DateTime, DailyEntry>{};
      for (var doc in entriesSnapshot.docs) {
        try {
          entries[DateTime.parse(doc.id)] = DailyEntry.fromMap(doc.data());
        } catch (e) {
          // Negeer ongeldige datums
        }
      }

      // 4. Navigeer naar de PhotoDetailScreen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PhotoDetailScreen(
              profile: profile,
              entries: entries,
              initialDate: DateTime.parse(widget.entryId),
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPermissionError = e.code == 'permission-denied';
          _errorMessage = _isPermissionError
              ? 'Je hebt geen toegang tot dit profiel. Mogelijk is je volgverzoek nog niet goedgekeurd.'
              : 'Fout bij openen van post: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Fout bij openen van post: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post Laden...'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Post wordt opgehaald...'),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPermissionError ? Icons.lock_outline : Icons.error_outline,
                      size: 64,
                      color: _isPermissionError ? Colors.orange : Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isPermissionError
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.red,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Terug'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
