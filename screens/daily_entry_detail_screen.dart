import 'package:flutter/material.dart';

class DailyEntryDetailScreen extends StatelessWidget {
  final String entryId;
  final String ownerId;

  const DailyEntryDetailScreen({
    super.key,
    required this.entryId,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail van de Post'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Notificatie ontvangen! We zijn op het juiste scherm.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Eigenaar ID: $ownerId'),
              const SizedBox(height: 10),
              Text('Post ID: $entryId'),
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
