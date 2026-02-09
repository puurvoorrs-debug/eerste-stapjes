class DailyEntry {
  final String photoUrl;
  bool isFavorite;

  DailyEntry({required this.photoUrl, this.isFavorite = false});

 factory DailyEntry.fromMap(Map<String, dynamic> map) {
    return DailyEntry(
      photoUrl: map['photoUrl'] as String,
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'photoUrl': photoUrl,
      'isFavorite': isFavorite,
    };
  }
}
