class TasteProfile {
  final String username;
  final int totalWatched;
  final int totalRated;
  final int totalInWatchlist;
  final Map<String, int> genreCounts; // Nome genere -> conteggio
  final Map<String, double> genrePercentages; // Nome genere -> percentuale (0.0 - 100.0)
  final List<String> topDirectors;
  final Map<String, int> directorFilmCounts; // Nome regista -> numero di film visti
  final List<String> topMultiGenres; // es: "Fantascienza & Thriller"
  final Map<String, double> multiGenrePercentages;
  final List<String> topSubgenres; // es: "Sci-Fi Psicologico", "Neo-Noir", "Dystopia"
  final double averageRating;
  final DateTime lastSync;

  const TasteProfile({
    required this.username,
    required this.totalWatched,
    required this.totalRated,
    required this.totalInWatchlist,
    required this.genreCounts,
    required this.genrePercentages,
    required this.topDirectors,
    this.directorFilmCounts = const {},
    this.topMultiGenres = const [],
    this.multiGenrePercentages = const {},
    this.topSubgenres = const [],
    required this.averageRating,
    required this.lastSync,
  });

  List<String> get topGenres {
    final entries = genrePercentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  factory TasteProfile.empty() {
    return TasteProfile(
      username: '',
      totalWatched: 0,
      totalRated: 0,
      totalInWatchlist: 0,
      genreCounts: {},
      genrePercentages: {},
      topDirectors: [],
      directorFilmCounts: {},
      topMultiGenres: [],
      multiGenrePercentages: {},
      topSubgenres: [],
      averageRating: 0.0,
      lastSync: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'totalWatched': totalWatched,
      'totalRated': totalRated,
      'totalInWatchlist': totalInWatchlist,
      'genreCounts': genreCounts,
      'genrePercentages': genrePercentages,
      'topDirectors': topDirectors,
      'directorFilmCounts': directorFilmCounts,
      'topMultiGenres': topMultiGenres,
      'multiGenrePercentages': multiGenrePercentages,
      'topSubgenres': topSubgenres,
      'averageRating': averageRating,
      'lastSync': lastSync.toIso8601String(),
    };
  }

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    return TasteProfile(
      username: json['username'] ?? '',
      totalWatched: json['totalWatched'] ?? 0,
      totalRated: json['totalRated'] ?? 0,
      totalInWatchlist: json['totalInWatchlist'] ?? 0,
      genreCounts: Map<String, int>.from(json['genreCounts'] ?? {}),
      genrePercentages: Map<String, double>.from(
        (json['genrePercentages'] ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      topDirectors: List<String>.from(json['topDirectors'] ?? []),
      directorFilmCounts: Map<String, int>.from(
        (json['directorFilmCounts'] ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      ),
      topMultiGenres: List<String>.from(json['topMultiGenres'] ?? []),
      multiGenrePercentages: Map<String, double>.from(
        (json['multiGenrePercentages'] ?? {}).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      ),
      topSubgenres: List<String>.from(json['topSubgenres'] ?? []),
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'])
          : DateTime.now(),
    );
  }
}
