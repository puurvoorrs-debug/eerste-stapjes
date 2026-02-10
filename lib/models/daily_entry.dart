class DailyEntry {
  final String photoUrl;
  final String description;
  final List<String> favoritedBy; // Voor persoonlijke favorieten (ster-icoon)
  final List<String> likes;       // Voor openbare likes (hart-icoon)

  DailyEntry({
    required this.photoUrl,
    this.description = '',
    this.favoritedBy = const [],
    this.likes = const [],
  });

  // Helper method om te checken of een specifieke gebruiker deze entry als favoriet heeft
  bool isFavoritedBy(String userId) {
    return favoritedBy.contains(userId);
  }

  // Helper method om te checken of een specifieke gebruiker deze entry heeft geliket
  bool isLikedBy(String userId) {
    return likes.contains(userId);
  }

  factory DailyEntry.fromMap(Map<String, dynamic> map) {
    final List<dynamic> favoritedByList = map['favoritedBy'] ?? [];
    final List<dynamic> likesList = map['likes'] ?? [];
    return DailyEntry(
      photoUrl: map['photoUrl'] as String,
      description: map['description'] as String? ?? '',
      favoritedBy: favoritedByList.cast<String>().toList(),
      likes: likesList.cast<String>().toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'description': description,
      'favoritedBy': favoritedBy,
      'likes': likes,
    };
  }
}
