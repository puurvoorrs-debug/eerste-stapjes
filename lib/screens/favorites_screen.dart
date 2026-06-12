import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/profile.dart';
import '../widgets/animated_footsteps_circle.dart';
import '../models/daily_entry.dart';
import '../providers/locale_provider.dart';

class FavoritesScreen extends StatelessWidget {
  final Profile profile;
  final Map<DateTime, DailyEntry> entries;

  const FavoritesScreen(
      {super.key, required this.profile, required this.entries});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    final favoriteEntries = entries.entries
        .where((entry) =>
            currentUser != null && entry.value.isFavoritedBy(currentUser.uid))
        .toList();

    // Sort by date, descending
    favoriteEntries.sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Mijn Favorieten', 'My Favorites')),
      ),
      body: favoriteEntries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border, size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('Je hebt nog geen favorieten gemarkeerd.',
                        'You have not marked any favorites yet.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(10.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
              ),
              itemCount: favoriteEntries.length,
              itemBuilder: (context, index) {
                final entry = favoriteEntries[index];
                return GestureDetector(
                  onTap: () {
                    // Pop back to CalendarScreen and navigate to the selected day
                    Navigator.pop(context, entry.key);
                  },
                  child: GridTile(
                    footer: GridTileBar(
                      backgroundColor: Colors.black54,
                      title: Text(
                        DateFormat('d MMM yyyy', context.tr('nl_NL', 'en_US'))
                            .format(entry.key),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.network(
                        entry.value.photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          return progress == null
                              ? child
                              : const Center(
                                  child: AnimatedFootstepsCircle(
                                    size: 60,
                                    showCircle: false,
                                  ),
                                );
                        },
                        errorBuilder: (context, error, stack) => const Center(
                            child: Icon(Icons.broken_image,
                                color: Colors.grey, size: 40)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
