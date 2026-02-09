import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/profile.dart';
import '../models/daily_entry.dart';

class FavoritesScreen extends StatelessWidget {
  final Profile profile;
  final Map<DateTime, DailyEntry> entries;

  const FavoritesScreen({super.key, required this.profile, required this.entries});

  @override
  Widget build(BuildContext context) {
    final favoriteEntries = entries.entries
        .where((entry) => entry.value.isFavorite)
        .toList();
        
    // Sort by date, descending
    favoriteEntries.sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        title: Text('Favorieten van ${profile.name}', style: const TextStyle(fontFamily: 'Pacifico', fontSize: 22)),
      ),
      body: favoriteEntries.isEmpty
          ? const Center(
              child: Text(
                'Je hebt nog geen favorieten.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 columns for better view
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
              ),
              itemCount: favoriteEntries.length,
              itemBuilder: (context, index) {
                final entry = favoriteEntries[index];
                return GridTile(
                  footer: GridTileBar(
                    backgroundColor: Colors.black45,
                    title: Text(DateFormat('d MMM yyyy', 'nl_NL').format(entry.key)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      entry.value.photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                          return progress == null ? child : const Center(child: CircularProgressIndicator());
                      },
                       errorBuilder: (context, error, stack) => const Center(child: Icon(Icons.error, color: Colors.red, size: 40)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
