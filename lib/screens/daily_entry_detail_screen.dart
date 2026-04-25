import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _loadDataAndNavigate();
  }

  Future<void> _loadDataAndNavigate() async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // 1. Fetch Profile
      final profileDoc = await firestore.collection('profiles').doc(widget.profileId).get();
      if (!profileDoc.exists) {
        throw Exception('Profiel niet gevonden.');
      }
      final profile = Profile.fromMap(profileDoc.data()!, profileDoc.id);

      // 2. Fetch all entries for this profile to allow swiping
      final entriesSnapshot = await firestore.collection('profiles').doc(widget.profileId).collection('daily_entries').get();
      final entries = <DateTime, DailyEntry>{};
      for (var doc in entriesSnapshot.docs) {
        try {
          entries[DateTime.parse(doc.id)] = DailyEntry.fromMap(doc.data());
        } catch (e) {
          // Ignore invalid dates
        }
      }

      // 3. Navigate to PhotoDetailScreen
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
          padding: const EdgeInsets.all(16.0),
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
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Terug'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
