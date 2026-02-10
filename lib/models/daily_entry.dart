class DailyEntry {
  final String photoUrl;
  final List<String> favoritedBy;

  DailyEntry({required this.photoUrl, this.favoritedBy = const []});

  // Helper method to check if a specific user has favorited this entry
  bool isFavoritedBy(String userId) {
    return favoritedBy.contains(userId);
  }

  factory DailyEntry.fromMap(Map<String, dynamic> map) {
    final List<dynamic> favoritedByList = map['favoritedBy'] ?? [];
    return DailyEntry(
      photoUrl: map['photoUrl'] as String,
      favoritedBy: favoritedByList.cast<String>().toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'favoritedBy': favoritedBy,
    };
  }
}
